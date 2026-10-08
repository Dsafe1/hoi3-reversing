// Exports the C++ class hierarchy of a 32-bit MSVC binary, recovered from its
// RTTI metadata, as an indented tree plus a JSON document.
//
// The tree is meant to be read; the JSON is meant to be consumed by tooling. For
// each class the export records its direct bases (with subobject offsets), its
// vftables, and the virtual functions it *introduces* as opposed to inherits.
//
// Nothing here is specific to one program. Retarget it by adjusting
// LIBRARY_NAMESPACES / LIBRARY_PREFIXES, which decide what counts as library
// noise rather than application code.
//
// This deliberately re-parses RTTI instead of reading back what
// ReconstructClassesFromRtti wrote, so it stands alone on any freshly imported
// MSVC binary. Ghidra has no queryable field for inheritance edges, so there
// would be nothing to read back regardless.
//
// Runs in the GUI (prompts for an output directory) or headless:
//   analyzeHeadless <proj-dir> <proj> -import target.exe -noanalysis \
//       -scriptPath <this-dir> -postScript ExportClassHierarchy.java <out-dir>
// Only memory is required, so -noanalysis is fine.
//
//@author OpenHOI3
//@category C++
//@keybinding
//@menupath
//@toolbar

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.MemoryBlock;

public class ExportClassHierarchy extends GhidraScript {

	// ---- tunables -----------------------------------------------------------

	private static final Set<String> LIBRARY_NAMESPACES = new HashSet<>(Arrays.asList(
		"std", "stdext", "__gnu_cxx", "luabind", "boost", "detail", "fpml",
		"Concurrency", "ATL", "WTL", "_com_error"));

	private static final String[] LIBRARY_PREFIXES = {
		"type_info", "bad_", "exception", "_", "?", "$", "AutoPtr", "Loki"
	};

	private static final int MAX_VFTABLE_SLOTS = 4096;

	// ---- model --------------------------------------------------------------

	private static final class RttiClass {
		String mangled;
		String name;
		long typeDescriptor;
		long chd;
		int attributes;
		final List<BaseRef> directBases = new ArrayList<>();
		final Set<RttiClass> allAncestors = new LinkedHashSet<>();
		final TreeMap<Integer, Vftable> vftables = new TreeMap<>();
		boolean library;

		@Override
		public String toString() {
			return name;
		}
	}

	private static final class BaseRef {
		RttiClass base;
		int mdisp;
		boolean virtualBase;
	}

	private static final class Vftable {
		long addr;
		int objOffset;
		final List<Long> slots = new ArrayList<>();
	}

	private static final class Blk {
		long start;
		long end;
		byte[] data;
		boolean exec;
	}

	// ---- state --------------------------------------------------------------

	private final List<Blk> blocks = new ArrayList<>();
	private final List<Blk> dataBlocks = new ArrayList<>();
	private final Map<Long, RttiClass> classesByTd = new HashMap<>();
	private final Set<Long> colPointerSites = new HashSet<>();

	// =========================================================================

	@Override
	public void run() throws Exception {
		if (currentProgram == null) {
			println("No program open.");
			return;
		}
		if (currentProgram.getDefaultPointerSize() != 4) {
			println("This script implements the 32-bit MSVC RTTI layout; the current " +
				"program is " + (currentProgram.getDefaultPointerSize() * 8) + "-bit.");
			return;
		}

		File outDir = resolveOutputDir();
		if (outDir == null) {
			println("No output directory chosen.");
			return;
		}

		loadBlocks();
		Set<Long> typeDescriptors = findTypeDescriptors();
		println("Type descriptors: " + typeDescriptors.size());
		if (typeDescriptors.isEmpty()) {
			println("No MSVC RTTI found. Nothing to export.");
			return;
		}

		List<Long> cols = findCompleteObjectLocators(typeDescriptors);
		println("Complete object locators: " + cols.size());

		buildClasses(cols);
		resolveHierarchy();
		locateVftables(cols);
		Map<Long, RttiClass> owners = attributeVirtualFunctions();

		List<RttiClass> game = new ArrayList<>();
		for (RttiClass c : classesByTd.values()) {
			if (!c.library) {
				game.add(c);
			}
		}
		game.sort(Comparator.comparing(c -> c.name));

		String stem = stemOf(currentProgram.getName());
		File treeFile = new File(outDir, stem + "-class-hierarchy.txt");
		File jsonFile = new File(outDir, stem + "-classes.json");

		int roots = writeTree(treeFile, game, owners);
		writeJson(jsonFile, owners);

		println("Classes: " + game.size() + " application, " +
			(classesByTd.size() - game.size()) + " library/template");
		println("Virtual functions attributed: " + owners.size());
		println("Wrote " + treeFile.getAbsolutePath() + " (" + roots + " roots)");
		println("Wrote " + jsonFile.getAbsolutePath());
	}

	private File resolveOutputDir() throws Exception {
		String[] args = getScriptArgs();
		if (args != null && args.length > 0) {
			File f = new File(args[0]);
			if (!f.isDirectory() && !f.mkdirs()) {
				println("Cannot create output directory: " + f);
				return null;
			}
			return f;
		}
		return askDirectory("Export class hierarchy to", "Choose");
	}

	private static String stemOf(String programName) {
		int dot = programName.lastIndexOf('.');
		String stem = dot > 0 ? programName.substring(0, dot) : programName;
		return sanitize(stem);
	}

	// ---- memory plumbing ----------------------------------------------------

	private void loadBlocks() throws Exception {
		for (MemoryBlock b : currentProgram.getMemory().getBlocks()) {
			if (!b.isInitialized() || b.isVolatile()) {
				continue;
			}
			long size = b.getSize();
			if (size <= 0 || size > Integer.MAX_VALUE) {
				continue;
			}
			Blk blk = new Blk();
			blk.start = b.getStart().getOffset();
			blk.end = blk.start + size;
			blk.data = new byte[(int) size];
			b.getBytes(b.getStart(), blk.data);
			blk.exec = b.isExecute();
			blocks.add(blk);
			if (!blk.exec) {
				dataBlocks.add(blk);
			}
		}
	}

	private Blk blockOf(long va) {
		for (int i = 0; i < blocks.size(); i++) {
			Blk b = blocks.get(i);
			if (va >= b.start && va < b.end) {
				return b;
			}
		}
		return null;
	}

	private boolean inImage(long va) {
		return blockOf(va) != null;
	}

	private boolean inExec(long va) {
		Blk b = blockOf(va);
		return b != null && b.exec;
	}

	private int readInt(long va) {
		Blk b = blockOf(va);
		if (b == null || va + 4 > b.end) {
			return 0;
		}
		return readInt(b, (int) (va - b.start));
	}

	private static int readInt(Blk b, int off) {
		return (b.data[off] & 0xFF)
			| ((b.data[off + 1] & 0xFF) << 8)
			| ((b.data[off + 2] & 0xFF) << 16)
			| ((b.data[off + 3] & 0xFF) << 24);
	}

	private static long u32(int v) {
		return v & 0xFFFFFFFFL;
	}

	// ---- RTTI parse ---------------------------------------------------------

	/** TypeDescriptor is { void* pVFTable; void* spare; char name[]; }. */
	private Set<Long> findTypeDescriptors() throws Exception {
		Set<Long> found = new HashSet<>();
		monitor.setMessage("Scanning for RTTI type descriptors");
		for (Blk b : dataBlocks) {
			monitor.checkCancelled();
			byte[] d = b.data;
			for (int i = 0; i + 4 < d.length; i++) {
				if (d[i] != '.' || d[i + 1] != '?' || d[i + 2] != 'A') {
					continue;
				}
				if (d[i + 3] != 'V' && d[i + 3] != 'U') {
					continue;
				}
				long tdVa = b.start + i - 8;
				if (tdVa < b.start || !inImage(u32(readInt(tdVa)))) {
					continue;
				}
				found.add(tdVa);
			}
		}
		return found;
	}

	private String readMangledName(long tdVa) {
		Blk b = blockOf(tdVa + 8);
		if (b == null) {
			return null;
		}
		int off = (int) (tdVa + 8 - b.start);
		StringBuilder sb = new StringBuilder();
		while (off < b.data.length && b.data[off] != 0) {
			sb.append((char) (b.data[off] & 0xFF));
			off++;
			if (sb.length() > 4096) {
				return null;
			}
		}
		return sb.toString();
	}

	private List<Long> findCompleteObjectLocators(Set<Long> tds) throws Exception {
		List<Long> cols = new ArrayList<>();
		monitor.setMessage("Scanning for complete object locators");
		for (Blk b : dataBlocks) {
			monitor.checkCancelled();
			byte[] d = b.data;
			for (int off = 0; off + 20 <= d.length; off += 4) {
				if (readInt(b, off) != 0) {
					continue;
				}
				int objOffset = readInt(b, off + 4);
				int cdOffset = readInt(b, off + 8);
				if (objOffset < 0 || objOffset > 0x100000 || cdOffset < 0 ||
					cdOffset > 0x10000) {
					continue;
				}
				if (!tds.contains(u32(readInt(b, off + 12)))) {
					continue;
				}
				if (!isPlausibleChd(u32(readInt(b, off + 16)))) {
					continue;
				}
				cols.add(b.start + off);
			}
		}
		return cols;
	}

	private boolean isPlausibleChd(long chd) {
		if (!inImage(chd) || readInt(chd) != 0) {
			return false;
		}
		int attrs = readInt(chd + 4);
		if (attrs < 0 || attrs > 7) {
			return false;
		}
		int numBases = readInt(chd + 8);
		if (numBases < 1 || numBases > 2000) {
			return false;
		}
		long bca = u32(readInt(chd + 12));
		return inImage(bca) && inImage(bca + 4L * numBases - 4);
	}

	private void buildClasses(List<Long> cols) {
		for (long col : cols) {
			intern(u32(readInt(col + 12)), u32(readInt(col + 16)));
		}
		for (RttiClass c : new ArrayList<>(classesByTd.values())) {
			if (c.chd == 0) {
				continue;
			}
			int numBases = readInt(c.chd + 8);
			long bca = u32(readInt(c.chd + 12));
			for (int i = 0; i < numBases; i++) {
				long bcd = u32(readInt(bca + 4L * i));
				if (!inImage(bcd)) {
					continue;
				}
				long pTd = u32(readInt(bcd));
				if (!classesByTd.containsKey(pTd) && inImage(pTd)) {
					intern(pTd, 0);
				}
			}
		}
	}

	private RttiClass intern(long td, long chd) {
		RttiClass existing = classesByTd.get(td);
		if (existing != null) {
			if (existing.chd == 0 && chd != 0) {
				existing.chd = chd;
				existing.attributes = readInt(chd + 4);
			}
			return existing;
		}
		String mangled = readMangledName(td);
		if (mangled == null || mangled.isEmpty()) {
			return null;
		}
		RttiClass c = new RttiClass();
		c.mangled = mangled;
		c.name = demangleTypeName(mangled);
		c.typeDescriptor = td;
		c.chd = chd;
		c.attributes = chd != 0 ? readInt(chd + 4) : 0;
		c.library = isLibraryType(mangled, c.name);
		classesByTd.put(td, c);
		return c;
	}

	/**
	 * ".?AVCBar@NS@@" -> "NS::CBar". Scope components are sanitised identically
	 * to ReconstructClassesFromRtti so exported names match the namespaces in the
	 * program database; in particular MSVC's per-translation-unit anonymous
	 * namespace tag "?A0x1234abcd" becomes "_A0x1234abcd". Those tags are kept
	 * rather than dropped because distinct translation units routinely declare
	 * classes of the same name.
	 */
	private static String demangleTypeName(String mangled) {
		String s = mangled;
		if (s.startsWith(".?AV") || s.startsWith(".?AU")) {
			s = s.substring(4);
		}
		while (s.endsWith("@")) {
			s = s.substring(0, s.length() - 1);
		}
		if (s.isEmpty()) {
			return mangled;
		}
		List<String> scopes = new ArrayList<>(Arrays.asList(s.split("@")));
		Collections.reverse(scopes);
		List<String> clean = new ArrayList<>(scopes.size());
		for (String scope : scopes) {
			clean.add(sanitize(scope));
		}
		return String.join("::", clean);
	}

	private static boolean isLibraryType(String mangled, String name) {
		if (mangled.contains("?$") || name.contains("?$") || name.contains("<")) {
			return true;
		}
		for (String part : name.split("::")) {
			if (LIBRARY_NAMESPACES.contains(part)) {
				return true;
			}
		}
		String leaf = name.contains("::") ? name.substring(name.lastIndexOf("::") + 2) : name;
		for (String p : LIBRARY_PREFIXES) {
			if (leaf.startsWith(p)) {
				return true;
			}
		}
		return leaf.isEmpty();
	}

	private void resolveHierarchy() {
		for (RttiClass c : classesByTd.values()) {
			if (c.chd == 0) {
				continue;
			}
			int numBases = readInt(c.chd + 8);
			long bca = u32(readInt(c.chd + 12));
			parseBaseRange(c, bca, 1, numBases - 1, 0, numBases);
		}
		for (RttiClass c : classesByTd.values()) {
			collectAncestors(c, c, new HashSet<RttiClass>());
		}
	}

	private void parseBaseRange(RttiClass owner, long bca, int start, int count,
			int ownerDisp, int totalEntries) {
		int i = start;
		int end = start + count;
		while (i < end && i < totalEntries) {
			long bcd = u32(readInt(bca + 4L * i));
			if (!inImage(bcd)) {
				return;
			}
			long pTd = u32(readInt(bcd));
			int contained = readInt(bcd + 4);
			int mdisp = readInt(bcd + 8);
			int pdisp = readInt(bcd + 12);
			if (contained < 0 || contained > totalEntries) {
				return;
			}
			RttiClass base = classesByTd.get(pTd);
			if (base != null && base != owner) {
				addDirectBase(owner, base, mdisp - ownerDisp, pdisp != -1);
				if (contained > 0) {
					parseBaseRange(base, bca, i + 1, contained, mdisp, totalEntries);
				}
			}
			i += 1 + contained;
		}
	}

	private void addDirectBase(RttiClass owner, RttiClass base, int disp, boolean virt) {
		for (BaseRef existing : owner.directBases) {
			if (existing.base == base) {
				return;
			}
		}
		BaseRef ref = new BaseRef();
		ref.base = base;
		ref.mdisp = disp;
		ref.virtualBase = virt;
		owner.directBases.add(ref);
	}

	private void collectAncestors(RttiClass target, RttiClass current, Set<RttiClass> seen) {
		if (!seen.add(current)) {
			return;
		}
		for (BaseRef ref : current.directBases) {
			if (ref.base != target) {
				target.allAncestors.add(ref.base);
			}
			collectAncestors(target, ref.base, seen);
		}
	}

	private void locateVftables(List<Long> cols) throws Exception {
		Set<Long> colSet = new HashSet<>(cols);
		Map<Long, Long> vftableToCol = new HashMap<>();
		monitor.setMessage("Locating vftables");
		for (Blk b : dataBlocks) {
			monitor.checkCancelled();
			for (int off = 0; off + 4 <= b.data.length; off += 4) {
				long value = u32(readInt(b, off));
				if (colSet.contains(value)) {
					long site = b.start + off;
					colPointerSites.add(site);
					vftableToCol.put(site + 4, value);
				}
			}
		}
		for (Map.Entry<Long, Long> e : vftableToCol.entrySet()) {
			monitor.checkCancelled();
			long col = e.getValue();
			RttiClass owner = classesByTd.get(u32(readInt(col + 12)));
			if (owner == null) {
				continue;
			}
			Vftable vt = new Vftable();
			vt.addr = e.getKey();
			vt.objOffset = readInt(col + 4);
			long addr = vt.addr;
			while (vt.slots.size() < MAX_VFTABLE_SLOTS) {
				if (colPointerSites.contains(addr)) {
					break;
				}
				long fn = u32(readInt(addr));
				if (!inExec(fn)) {
					break;
				}
				vt.slots.add(fn);
				addr += 4;
			}
			if (!vt.slots.isEmpty()) {
				owner.vftables.put(vt.objOffset, vt);
			}
		}
	}

	/** See ReconstructClassesFromRtti; identical rule, so both agree. */
	private Map<Long, RttiClass> attributeVirtualFunctions() {
		Map<Long, Set<RttiClass>> refs = new HashMap<>();
		for (RttiClass c : classesByTd.values()) {
			if (c.library) {
				continue;
			}
			for (Vftable vt : c.vftables.values()) {
				for (long fn : vt.slots) {
					Set<RttiClass> set = refs.get(fn);
					if (set == null) {
						set = new LinkedHashSet<>();
						refs.put(fn, set);
					}
					set.add(c);
				}
			}
		}
		Map<Long, RttiClass> owners = new HashMap<>();
		for (Map.Entry<Long, Set<RttiClass>> e : refs.entrySet()) {
			Set<RttiClass> holders = e.getValue();
			for (RttiClass candidate : holders) {
				boolean ancestorOfAll = true;
				for (RttiClass other : holders) {
					if (other != candidate && !other.allAncestors.contains(candidate)) {
						ancestorOfAll = false;
						break;
					}
				}
				if (ancestorOfAll) {
					owners.put(e.getKey(), candidate);
					break;
				}
			}
		}
		return owners;
	}

	// ---- rendering ----------------------------------------------------------

	/** The base sharing the object's address, whose vftable the class extends. */
	private static RttiClass primaryBase(RttiClass c) {
		for (BaseRef ref : c.directBases) {
			if (ref.mdisp == 0 && !ref.virtualBase) {
				return ref.base;
			}
		}
		return c.directBases.isEmpty() ? null : c.directBases.get(0).base;
	}

	private int introducedCount(RttiClass c, Map<Long, RttiClass> owners) {
		int n = 0;
		for (Vftable vt : c.vftables.values()) {
			for (long fn : vt.slots) {
				if (owners.get(fn) == c) {
					n++;
				}
			}
		}
		return n;
	}

	private static int totalSlots(RttiClass c) {
		int n = 0;
		for (Vftable vt : c.vftables.values()) {
			n += vt.slots.size();
		}
		return n;
	}

	private int writeTree(File file, List<RttiClass> game, Map<Long, RttiClass> owners)
			throws IOException {
		Map<RttiClass, List<RttiClass>> children = new HashMap<>();
		List<RttiClass> roots = new ArrayList<>();
		for (RttiClass c : game) {
			RttiClass p = primaryBase(c);
			if (p != null && !p.library) {
				children.computeIfAbsent(p, k -> new ArrayList<>()).add(c);
			}
			else {
				roots.add(c);
			}
		}
		for (List<RttiClass> kids : children.values()) {
			kids.sort(Comparator.comparing(c -> c.name));
		}
		roots.sort(Comparator.comparing(c -> c.name));

		Set<RttiClass> emitted = new HashSet<>();
		List<String> lines = new ArrayList<>();
		for (RttiClass r : roots) {
			emit(r, 0, children, owners, emitted, lines);
		}
		for (RttiClass c : game) {          // reachable only via a library base
			if (!emitted.contains(c)) {
				emit(c, 0, children, owners, emitted, lines);
			}
		}

		try (PrintWriter w = new PrintWriter(file, StandardCharsets.UTF_8)) {
			w.println("Class hierarchy of " + currentProgram.getName());
			w.println("Recovered from MSVC RTTI by ghidra/ExportClassHierarchy.java.");
			w.println("Generated file - do not edit by hand.");
			w.println();
			w.println("Indentation follows the primary base: the one at offset 0, whose");
			w.println("vftable the derived class extends. Additional bases appear inline");
			w.println("as 'also:'. 'introduced' counts virtual functions first declared by");
			w.println("that class rather than inherited from an ancestor.");
			w.println();
			w.println("Names match the namespaces created by ReconstructClassesFromRtti.");
			w.println("A leading '_A0x...' scope is MSVC's anonymous namespace for one");
			w.println("translation unit; it is retained because different units declare");
			w.println("classes of the same name.");
			w.println();
			w.println(game.size() + " application classes, " + roots.size() + " roots, " +
				(classesByTd.size() - game.size()) + " library/template types excluded.");
			w.println("==============================================================================");
			w.println();
			for (String line : lines) {
				w.println(line);
			}
		}
		return roots.size();
	}

	private void emit(RttiClass c, int depth, Map<RttiClass, List<RttiClass>> children,
			Map<Long, RttiClass> owners, Set<RttiClass> emitted, List<String> lines) {
		String indent = "    ".repeat(depth);
		if (!emitted.add(c)) {
			lines.add(indent + c.name + "  (see above)");
			return;
		}
		RttiClass primary = primaryBase(c);
		List<String> notes = new ArrayList<>();
		StringBuilder extra = new StringBuilder();
		for (BaseRef ref : c.directBases) {
			if (ref.base == primary) {
				continue;
			}
			if (extra.length() > 0) {
				extra.append(", ");
			}
			extra.append(String.format("%s@0x%x", ref.base.name, ref.mdisp));
			if (ref.virtualBase) {
				extra.append(" virtual");
			}
		}
		if (extra.length() > 0) {
			notes.add("also: " + extra);
		}
		if (!c.vftables.isEmpty()) {
			notes.add(totalSlots(c) + " slots, " + introducedCount(c, owners) + " introduced");
		}
		lines.add(indent + c.name + (notes.isEmpty() ? "" : "  [" + String.join("; ", notes) + "]"));

		List<RttiClass> kids = children.get(c);
		if (kids != null) {
			for (RttiClass kid : kids) {
				emit(kid, depth + 1, children, owners, emitted, lines);
			}
		}
	}

	private void writeJson(File file, Map<Long, RttiClass> owners) throws IOException {
		List<RttiClass> all = new ArrayList<>(classesByTd.values());
		all.sort(Comparator.comparing(c -> c.name));

		try (PrintWriter w = new PrintWriter(file, StandardCharsets.UTF_8)) {
			w.println("{");
			w.println(" \"source\": " + q(currentProgram.getName()) + ",");
			w.println(" \"image_base\": " +
				q(String.format("0x%08x", currentProgram.getImageBase().getOffset())) + ",");
			w.println(" \"class_count\": " + all.size() + ",");
			w.println(" \"classes\": [");
			for (int idx = 0; idx < all.size(); idx++) {
				RttiClass c = all.get(idx);
				w.println("  {");
				w.println("   \"name\": " + q(c.name) + ",");
				w.println("   \"mangled\": " + q(c.mangled) + ",");
				w.println("   \"library\": " + c.library + ",");

				StringBuilder bases = new StringBuilder();
				for (BaseRef ref : c.directBases) {
					if (bases.length() > 0) {
						bases.append(", ");
					}
					bases.append("{\"name\": ").append(q(ref.base.name))
						.append(", \"offset\": ").append(ref.mdisp)
						.append(", \"virtual\": ").append(ref.virtualBase)
						.append(", \"library\": ").append(ref.base.library).append("}");
				}
				w.println("   \"bases\": [" + bases + "],");

				StringBuilder vfts = new StringBuilder();
				for (Vftable vt : c.vftables.values()) {
					if (vfts.length() > 0) {
						vfts.append(", ");
					}
					vfts.append("{\"object_offset\": ").append(vt.objOffset)
						.append(", \"address\": ")
						.append(q(String.format("0x%08x", vt.addr)))
						.append(", \"slots\": ").append(vt.slots.size()).append("}");
				}
				w.println("   \"vftables\": [" + vfts + "],");

				StringBuilder intro = new StringBuilder();
				for (Vftable vt : c.vftables.values()) {
					for (int slot = 0; slot < vt.slots.size(); slot++) {
						long fn = vt.slots.get(slot);
						if (owners.get(fn) != c) {
							continue;
						}
						if (intro.length() > 0) {
							intro.append(", ");
						}
						intro.append("{\"slot\": ").append(slot)
							.append(", \"vftable_offset\": ").append(vt.objOffset)
							.append(", \"address\": ")
							.append(q(String.format("0x%08x", fn))).append("}");
					}
				}
				w.println("   \"introduces\": [" + intro + "]");
				w.println(idx == all.size() - 1 ? "  }" : "  },");
			}
			w.println(" ]");
			w.println("}");
		}
	}

	private static String q(String s) {
		StringBuilder sb = new StringBuilder(s.length() + 2);
		sb.append('"');
		for (char ch : s.toCharArray()) {
			switch (ch) {
				case '"' -> sb.append("\\\"");
				case '\\' -> sb.append("\\\\");
				case '\n' -> sb.append("\\n");
				case '\r' -> sb.append("\\r");
				case '\t' -> sb.append("\\t");
				default -> {
					if (ch < 0x20 || ch > 0x7E) {
						sb.append(String.format("\\u%04x", (int) ch));
					}
					else {
						sb.append(ch);
					}
				}
			}
		}
		return sb.append('"').toString();
	}

	private static String sanitize(String s) {
		StringBuilder sb = new StringBuilder(s.length());
		for (char ch : s.toCharArray()) {
			sb.append(Character.isLetterOrDigit(ch) || ch == '_' ? ch : '_');
		}
		String out = sb.toString();
		return out.isEmpty() ? "anon" : out;
	}
}
