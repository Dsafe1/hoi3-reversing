// Reconstructs the C++ class inheritance graph of a 32-bit MSVC binary from its
// RTTI metadata, then assigns every virtual function to the most basal class that
// declares it (i.e. the class that actually introduced the slot, not every derived
// class that merely inherits it).
//
// Written for Hearts of Iron 3: Their Finest Hour (hoi3_tfh.exe), which is a PE32
// x86 MSVC build carrying complete RTTI. Only "game" classes are processed;
// luabind/STL/boost template instantiations are skipped.
//
// The RTTI structures are parsed straight out of memory rather than through
// Ghidra's own RTTI classes, so this does not depend on which analyzers were run
// or on internal APIs that shift between Ghidra releases.
//
//@author OpenHOI3
//@category C++
//@keybinding
//@menupath
//@toolbar

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
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.GhidraClass;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Namespace;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;

public class ReconstructClassesFromRtti extends GhidraScript {

	// ---- tunables -----------------------------------------------------------

	/** Namespace roots that mark a type as library code rather than game code. */
	private static final Set<String> LIBRARY_NAMESPACES = new HashSet<>(Arrays.asList(
		"std", "stdext", "__gnu_cxx", "luabind", "boost", "detail", "fpml",
		"Concurrency", "ATL", "WTL", "_com_error"));

	/** Leading tokens that mark a bare type name as library/runtime scaffolding. */
	private static final String[] LIBRARY_PREFIXES = {
		"type_info", "bad_", "exception", "_", "?", "$", "AutoPtr", "Loki"
	};

	/** Hard ceiling on vftable length, to contain a runaway scan. */
	private static final int MAX_VFTABLE_SLOTS = 4096;

	// ---- model --------------------------------------------------------------

	private static final class RttiClass {
		String mangled;                     // ".?AVCFoo@@"
		String name;                        // "CFoo" or "NS::CFoo"
		long typeDescriptor;
		long chd;                           // class hierarchy descriptor VA
		int attributes;
		final List<BaseRef> directBases = new ArrayList<>();
		final Set<RttiClass> allAncestors = new LinkedHashSet<>();
		final TreeMap<Integer, Vftable> vftables = new TreeMap<>();  // objOffset -> table
		boolean library;
		GhidraClass ns;

		@Override
		public String toString() {
			return name;
		}
	}

	/** A direct base together with where it sits inside the derived object. */
	private static final class BaseRef {
		RttiClass base;
		int mdisp;              // offset of the base subobject
		boolean virtualBase;    // pdisp != -1 -> located via vbtable at runtime
	}

	private static final class Vftable {
		long addr;
		int objOffset;                          // COL.offset
		final List<Long> slots = new ArrayList<>();
	}

	/** One initialized memory block, slurped into a byte[] for fast scanning. */
	private static final class Blk {
		long start;
		long end;         // exclusive
		byte[] data;
		boolean exec;
		String name;
	}

	// ---- state --------------------------------------------------------------

	private final List<Blk> blocks = new ArrayList<>();
	private final List<Blk> dataBlocks = new ArrayList<>();
	private final Map<Long, RttiClass> classesByTd = new HashMap<>();
	private final Map<String, RttiClass> classesByName = new HashMap<>();
	private final Set<Long> colPointerSites = new HashSet<>();

	private int renamed;
	private int reparented;
	private int ambiguous;
	private int createdFunctions;

	// =========================================================================

	@Override
	public void run() throws Exception {
		if (currentProgram == null) {
			println("No program open.");
			return;
		}
		int ptrSize = currentProgram.getDefaultPointerSize();
		if (ptrSize != 4) {
			popup("This script implements the 32-bit MSVC RTTI layout, but the current\n" +
				"program has a " + (ptrSize * 8) + "-bit pointer size. 64-bit MSVC RTTI stores\n" +
				"image-base-relative offsets instead of absolute VAs and is not handled.");
			return;
		}

		loadBlocks();
		println("Scanned " + blocks.size() + " initialized blocks (" +
			dataBlocks.size() + " non-executable).");

		Set<Long> typeDescriptors = findTypeDescriptors();
		println("Type descriptors found: " + typeDescriptors.size());
		if (typeDescriptors.isEmpty()) {
			println("No MSVC RTTI type descriptors located. Nothing to do.");
			return;
		}

		List<Long> cols = findCompleteObjectLocators(typeDescriptors);
		println("Complete object locators found: " + cols.size());

		buildClasses(cols);
		println("Classes with RTTI: " + classesByTd.size());

		resolveHierarchy();
		int gameClasses = 0;
		for (RttiClass c : classesByTd.values()) {
			if (!c.library) {
				gameClasses++;
			}
		}
		println("Game classes (templates/library types excluded): " + gameClasses);

		locateVftables(cols);

		List<RttiClass> ordered = topologicalOrder();
		Map<Long, RttiClass> owners = attributeVirtualFunctions(ordered);

		applyToProgram(ordered, owners);

		println("");
		println("=== summary ===");
		println("  classes namespaced      : " + gameClasses);
		println("  functions re-parented   : " + reparented);
		println("  functions renamed       : " + renamed);
		println("  functions created       : " + createdFunctions);
		println("  ambiguous (folded) slots: " + ambiguous);
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
			blk.name = b.getName();
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

	/** Little-endian 32-bit read; returns 0 for addresses outside the image. */
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

	// ---- step 1: type descriptors ------------------------------------------

	/**
	 * A TypeDescriptor is { void* pVFTable; void* spare; char name[]; } so the
	 * mangled name begins 8 bytes in. Locating the ".?AV"/".?AU" tag therefore
	 * locates the structure.
	 */
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
				long nameVa = b.start + i;
				long tdVa = nameVa - 8;
				if (tdVa < b.start) {
					continue;
				}
				// The type_info vftable pointer must at least land inside the image.
				if (!inImage(u32(readInt(tdVa)))) {
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

	// ---- step 2: complete object locators ----------------------------------

	/**
	 * COL (32-bit): { DWORD signature; DWORD offset; DWORD cdOffset;
	 *                 DWORD pTypeDescriptor; DWORD pClassHierarchyDescriptor; }
	 */
	private List<Long> findCompleteObjectLocators(Set<Long> typeDescriptors) throws Exception {
		List<Long> cols = new ArrayList<>();
		monitor.setMessage("Scanning for complete object locators");
		for (Blk b : dataBlocks) {
			monitor.checkCancelled();
			byte[] d = b.data;
			for (int off = 0; off + 20 <= d.length; off += 4) {
				if (readInt(b, off) != 0) {                 // signature must be 0 on x86
					continue;
				}
				int objOffset = readInt(b, off + 4);
				int cdOffset = readInt(b, off + 8);
				if (objOffset < 0 || objOffset > 0x100000 || cdOffset < 0 || cdOffset > 0x10000) {
					continue;
				}
				long pTd = u32(readInt(b, off + 12));
				if (!typeDescriptors.contains(pTd)) {
					continue;
				}
				long pChd = u32(readInt(b, off + 16));
				if (!isPlausibleChd(pChd)) {
					continue;
				}
				cols.add(b.start + off);
			}
		}
		return cols;
	}

	/**
	 * CHD: { DWORD signature; DWORD attributes; DWORD numBaseClasses;
	 *        DWORD pBaseClassArray; }
	 */
	private boolean isPlausibleChd(long chd) {
		if (!inImage(chd)) {
			return false;
		}
		if (readInt(chd) != 0) {
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

	// ---- step 3: classes ----------------------------------------------------

	private void buildClasses(List<Long> cols) {
		for (long col : cols) {
			long pTd = u32(readInt(col + 12));
			long pChd = u32(readInt(col + 16));
			intern(pTd, pChd);
		}
		// Base class descriptors can name classes that never own a vftable of
		// their own (pure interfaces, or bases only ever used as subobjects).
		List<RttiClass> seed = new ArrayList<>(classesByTd.values());
		for (RttiClass c : seed) {
			harvestBaseDescriptors(c);
		}
	}

	private void harvestBaseDescriptors(RttiClass c) {
		int numBases = readInt(c.chd + 8);
		long bca = u32(readInt(c.chd + 12));
		for (int i = 0; i < numBases; i++) {
			long bcd = u32(readInt(bca + 4L * i));
			if (!inImage(bcd)) {
				continue;
			}
			long pTd = u32(readInt(bcd));
			if (classesByTd.containsKey(pTd) || !inImage(pTd)) {
				continue;
			}
			// A base descriptor carries no CHD pointer, so reuse the one hanging
			// off any COL that names the same type descriptor; failing that the
			// class is recorded with no hierarchy of its own.
			intern(pTd, 0);
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
		// Name collisions across distinct descriptors are possible; first wins,
		// and the loser stays reachable through classesByTd.
		classesByName.putIfAbsent(c.name, c);
		return c;
	}

	/**
	 * ".?AVCFoo@@"        -> "CFoo"
	 * ".?AVCBar@NS@@"     -> "NS::CBar"
	 * Templates are not decoded; they are filtered out as library types anyway.
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
		String[] parts = s.split("@");
		List<String> scopes = new ArrayList<>(Arrays.asList(parts));
		Collections.reverse(scopes);          // MSVC stores innermost-first
		return String.join("::", scopes);
	}

	private static boolean isLibraryType(String mangled, String name) {
		if (mangled.contains("?$") || name.contains("?$") || name.contains("<")) {
			return true;                       // template instantiation
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

	// ---- step 4: inheritance ------------------------------------------------

	/**
	 * The base class array is a preorder walk of the inheritance DAG: entry 0 is
	 * the class itself, and each entry is followed by its own {@code
	 * numContainedBases} descendants. Skipping those subtrees yields the direct
	 * bases; descending into them yields the direct bases of each base in turn.
	 *
	 * Descending matters because a class only owns a hierarchy descriptor if it
	 * owns a vftable, so pure interfaces that are never instantiated would
	 * otherwise come out parentless. Their parents are still described inside the
	 * base class arrays of everything that derives from them.
	 */
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

	/**
	 * Walks the preorder slice {@code [start, start+count)}, whose entries are
	 * exactly the bases contained in {@code owner}.
	 *
	 * Every PMD in the array is relative to the class owning the hierarchy
	 * descriptor, so nested displacements are rebased onto the intermediate class
	 * via {@code ownerDisp}.
	 */
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

	/** Adds an edge unless it is already known from some other derived class. */
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
			return;                                       // guards against RTTI cycles
		}
		for (BaseRef ref : current.directBases) {
			if (ref.base != target) {
				target.allAncestors.add(ref.base);
			}
			collectAncestors(target, ref.base, seen);
		}
	}

	// ---- step 5: vftables ---------------------------------------------------

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
					vftableToCol.put(site + 4, value);    // table starts after the COL ptr
				}
			}
		}

		for (Map.Entry<Long, Long> e : vftableToCol.entrySet()) {
			monitor.checkCancelled();
			long tableVa = e.getKey();
			long col = e.getValue();
			RttiClass owner = classesByTd.get(u32(readInt(col + 12)));
			if (owner == null) {
				continue;
			}
			Vftable vt = new Vftable();
			vt.addr = tableVa;
			vt.objOffset = readInt(col + 4);
			readSlots(vt);
			if (!vt.slots.isEmpty()) {
				owner.vftables.put(vt.objOffset, vt);
			}
		}
	}

	private void readSlots(Vftable vt) {
		long addr = vt.addr;
		while (vt.slots.size() < MAX_VFTABLE_SLOTS) {
			if (colPointerSites.contains(addr)) {
				break;                                    // start of the next vftable
			}
			long fn = u32(readInt(addr));
			if (!inExec(fn)) {
				break;
			}
			vt.slots.add(fn);
			addr += 4;
		}
	}

	// ---- step 6: attribution ------------------------------------------------

	/** Bases before derived, so the first claimant of a slot is the most basal. */
	private List<RttiClass> topologicalOrder() {
		List<RttiClass> out = new ArrayList<>();
		Set<RttiClass> done = new HashSet<>();
		List<RttiClass> all = new ArrayList<>(classesByTd.values());
		all.sort(Comparator.comparing(c -> c.name));
		for (RttiClass c : all) {
			visit(c, done, out, new HashSet<RttiClass>());
		}
		return out;
	}

	private void visit(RttiClass c, Set<RttiClass> done, List<RttiClass> out,
			Set<RttiClass> path) {
		if (done.contains(c) || !path.add(c)) {
			return;
		}
		for (BaseRef ref : c.directBases) {
			visit(ref.base, done, out, path);
		}
		if (done.add(c)) {
			out.add(c);
		}
		path.remove(c);
	}

	/**
	 * Maps each virtual function to the class that introduced it.
	 *
	 * A function appearing in several vftables is owned by whichever referencing
	 * class is an ancestor of all the others. When no such class exists the
	 * function is shared between unrelated hierarchies, which on an MSVC release
	 * build means identical-COMDAT-folding (/OPT:ICF) merged two distinct
	 * functions into one address. Those are left untouched rather than
	 * arbitrarily attributed.
	 */
	private Map<Long, RttiClass> attributeVirtualFunctions(List<RttiClass> ordered) {
		Map<Long, Set<RttiClass>> refs = new HashMap<>();
		for (RttiClass c : ordered) {
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
			RttiClass best = null;
			for (RttiClass candidate : holders) {
				boolean ancestorOfAll = true;
				for (RttiClass other : holders) {
					if (other != candidate && !other.allAncestors.contains(candidate)) {
						ancestorOfAll = false;
						break;
					}
				}
				if (ancestorOfAll) {
					best = candidate;
					break;
				}
			}
			if (best == null) {
				ambiguous++;
			}
			else {
				owners.put(e.getKey(), best);
			}
		}
		return owners;
	}

	// ---- step 7: write it back ---------------------------------------------

	private void applyToProgram(List<RttiClass> ordered, Map<Long, RttiClass> owners)
			throws Exception {
		SymbolTable st = currentProgram.getSymbolTable();

		monitor.setMessage("Creating class namespaces");
		for (RttiClass c : ordered) {
			monitor.checkCancelled();
			if (!c.library) {
				c.ns = ensureClass(st, c.name);
			}
		}

		monitor.setMessage("Assigning virtual functions");
		monitor.initialize(ordered.size());
		for (RttiClass c : ordered) {
			monitor.checkCancelled();
			monitor.incrementProgress(1);
			if (c.library || c.ns == null) {
				continue;
			}
			labelVftables(st, c);
			for (Vftable vt : c.vftables.values()) {
				for (int slot = 0; slot < vt.slots.size(); slot++) {
					long fn = vt.slots.get(slot);
					if (owners.get(fn) == c) {
						assignFunction(fn, c, slot, vt.objOffset);
					}
				}
			}
		}
	}

	/** Creates (or reuses) a GhidraClass, materialising any enclosing scopes. */
	private GhidraClass ensureClass(SymbolTable st, String qualified) throws Exception {
		Namespace parent = currentProgram.getGlobalNamespace();
		String[] parts = qualified.split("::");
		for (int i = 0; i < parts.length; i++) {
			String part = sanitize(parts[i]);
			boolean last = i == parts.length - 1;
			Namespace existing = st.getNamespace(part, parent);
			if (existing != null) {
				if (last && !(existing instanceof GhidraClass)) {
					return null;              // occupied by a plain namespace; leave it alone
				}
				parent = existing;
				continue;
			}
			parent = last ? st.createClass(parent, part, SourceType.ANALYSIS)
				: st.createNameSpace(parent, part, SourceType.ANALYSIS);
		}
		return parent instanceof GhidraClass ? (GhidraClass) parent : null;
	}

	private void labelVftables(SymbolTable st, RttiClass c) throws Exception {
		for (Vftable vt : c.vftables.values()) {
			Address addr = toAddr(vt.addr);
			String label = vt.objOffset == 0 ? "vftable"
				: String.format("vftable_0x%x", vt.objOffset);
			st.createLabel(addr, label, c.ns, SourceType.ANALYSIS);
			setPlateComment(addr, describeClass(c, vt));
		}
	}

	private String describeClass(RttiClass c, Vftable vt) {
		StringBuilder sb = new StringBuilder();
		sb.append(c.name).append("::").append(vt.objOffset == 0 ? "vftable"
			: String.format("vftable_0x%x", vt.objOffset));
		sb.append("  (").append(vt.slots.size()).append(" slots)\n");
		if (c.directBases.isEmpty()) {
			sb.append("root class\n");
		}
		else {
			sb.append("directly derives from:\n");
			for (BaseRef ref : c.directBases) {
				sb.append("    ").append(ref.base.name);
				sb.append(String.format(" @ 0x%x", ref.mdisp));
				if (ref.virtualBase) {
					sb.append(" (virtual base)");
				}
				if (ref.base.library) {
					sb.append(" [library type, not namespaced]");
				}
				sb.append('\n');
			}
		}
		if ((c.attributes & 1) != 0) {
			sb.append("multiple inheritance\n");
		}
		if ((c.attributes & 2) != 0) {
			sb.append("virtual inheritance\n");
		}
		return sb.toString();
	}

	private void assignFunction(long fnVa, RttiClass owner, int slot, int objOffset) {
		try {
			Address addr = toAddr(fnVa);
			Function f = getFunctionAt(addr);
			if (f == null) {
				f = createFunction(addr, null);
				if (f == null) {
					return;
				}
				createdFunctions++;
			}
			Symbol sym = f.getSymbol();
			boolean defaultName = sym == null || sym.getSource() == SourceType.DEFAULT;

			if (f.getParentNamespace() != owner.ns) {
				f.setParentNamespace(owner.ns);
				reparented++;
			}
			if (defaultName) {
				String base = objOffset == 0 ? "vf_" : String.format("vf%x_", objOffset);
				f.setName(String.format("%s%02d", base, slot), SourceType.ANALYSIS);
				renamed++;
			}
		}
		catch (Exception e) {
			println(String.format("  ! %s slot %d @ %08x: %s",
				owner.name, slot, fnVa, e.getMessage()));
		}
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
