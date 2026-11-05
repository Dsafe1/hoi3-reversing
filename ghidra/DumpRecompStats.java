// Read-only census of the program for a static-recompilation feasibility check.
// Writes functions.tsv, refs.tsv, mnemonics.tsv, jumps.tsv, compcalls.tsv, coverage.txt
// into the folder given as the first script argument. Changes nothing in the program.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.mem.*;
import java.io.*;
import java.util.*;

public class DumpRecompStats extends GhidraScript {

    static boolean isPrefix(int b) {
        return b == 0x66 || b == 0x67 || b == 0xF2 || b == 0xF3 || b == 0xF0 || b == 0x2E
            || b == 0x36 || b == 0x3E || b == 0x26 || b == 0x64 || b == 0x65;
    }

    long rva(Address a) { return a.getOffset() - currentProgram.getImageBase().getOffset(); }

    String hx(long v) { return "0x" + Long.toHexString(v).toUpperCase(); }

    @Override
    public void run() throws Exception {
        String outDir = getScriptArgs()[0];
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();
        ReferenceManager rm = currentProgram.getReferenceManager();
        Memory mem = currentProgram.getMemory();

        PrintWriter fw = new PrintWriter(new FileWriter(outDir + "/functions.tsv"));
        PrintWriter rw = new PrintWriter(new FileWriter(outDir + "/refs.tsv"));
        PrintWriter jw = new PrintWriter(new FileWriter(outDir + "/jumps.tsv"));
        PrintWriter cw = new PrintWriter(new FileWriter(outDir + "/compcalls.tsv"));
        fw.println("entry\tname\tranges\tinstrs\tthunk\tthunkTarget\tcc\tpurge\tnoreturn\tcustom\tx87\tsse\tmmx\tlock\tfs\tcompCallExt\tcompCallInt\tcompJump\tcompJumpUnres");
        rw.println("to\tfrom\ttype\tfromInstr");
        jw.println("at\tfunction\tresolved\ttargets\ttext");
        cw.println("at\tfunction\tkind\ttext");

        Map<String, Integer> mn = new TreeMap<>();
        AddressSet covered = new AddressSet();
        int nf = 0;
        for (Function f : fm.getFunctions(true)) {
            if (monitor.isCancelled()) break;
            nf++;
            AddressSetView body = f.getBody();
            covered.add(body);
            StringBuilder ranges = new StringBuilder();
            for (AddressRange r : body) {
                if (ranges.length() > 0) ranges.append(';');
                ranges.append(hx(rva(r.getMinAddress()))).append('-').append(hx(rva(r.getMaxAddress())));
            }
            int ins = 0, x87 = 0, sse = 0, mmx = 0, lock = 0, fs = 0, cce = 0, cci = 0, cj = 0, cju = 0;
            for (Instruction in : listing.getInstructions(body, true)) {
                ins++;
                mn.merge(in.getMnemonicString(), 1, Integer::sum);
                byte[] b = in.getBytes();
                int i = 0;
                while (i < b.length && isPrefix(b[i] & 0xFF)) {
                    if ((b[i] & 0xFF) == 0xF0) lock++;
                    if ((b[i] & 0xFF) == 0x64) fs++;
                    i++;
                }
                if (i < b.length) {
                    int op = b[i] & 0xFF;
                    if (op >= 0xD8 && op <= 0xDF) x87++;
                }
                String txt = in.toString();
                if (txt.contains("XMM")) sse++;
                else if (txt.matches(".*\\bMM[0-7]\\b.*")) mmx++;
                FlowType ft = in.getFlowType();
                if (ft.isComputed() && ft.isCall()) {
                    boolean ext = false;
                    for (Reference r : in.getReferencesFrom()) {
                        if (r.isExternalReference()) ext = true;
                        Address to = r.getToAddress();
                        Data d = listing.getDataAt(to);
                        if (d != null && d.isPointer() && d.getValue() instanceof Address
                            && ((Address) d.getValue()).isExternalAddress()) ext = true;
                        if (r.getToAddress().isExternalAddress()) ext = true;
                    }
                    if (ext) cce++; else { cci++; cw.println(hx(rva(in.getAddress())) + "\t" + hx(rva(f.getEntryPoint())) + "\tint\t" + txt); }
                } else if (ft.isComputed() && ft.isJump()) {
                    cj++;
                    int targets = 0;
                    boolean ext = false;
                    for (Reference r : in.getReferencesFrom()) {
                        if (r.getReferenceType().isFlow()) targets++;
                        if (r.getToAddress().isExternalAddress()) ext = true;
                        Data d = listing.getDataAt(r.getToAddress());
                        if (d != null && d.isPointer() && d.getValue() instanceof Address
                            && ((Address) d.getValue()).isExternalAddress()) ext = true;
                    }
                    boolean resolved = targets > 0 || ext;
                    if (!resolved) cju++;
                    jw.println(hx(rva(in.getAddress())) + "\t" + hx(rva(f.getEntryPoint())) + "\t" + (ext ? "ext" : (resolved ? "yes" : "no")) + "\t" + targets + "\t" + txt);
                }
            }
            Function tt = f.isThunk() ? f.getThunkedFunction(false) : null;
            String ttn = tt == null ? "" : (tt.isExternal() ? "EXT:" + tt.getName(true) : hx(rva(tt.getEntryPoint())));
            fw.println(hx(rva(f.getEntryPoint())) + "\t" + f.getName(true) + "\t" + ranges + "\t" + ins + "\t"
                + (f.isThunk() ? 1 : 0) + "\t" + ttn + "\t" + f.getCallingConventionName() + "\t" + f.getStackPurgeSize() + "\t"
                + (f.hasNoReturn() ? 1 : 0) + "\t" + (f.hasCustomVariableStorage() ? 1 : 0) + "\t"
                + x87 + "\t" + sse + "\t" + mmx + "\t" + lock + "\t" + fs + "\t" + cce + "\t" + cci + "\t" + cj + "\t" + cju);
            for (Reference r : rm.getReferencesTo(f.getEntryPoint())) {
                Instruction fi = listing.getInstructionAt(r.getFromAddress());
                String from = r.getFromAddress().isMemoryAddress() ? hx(rva(r.getFromAddress())) : r.getFromAddress().toString();
                rw.println(hx(rva(f.getEntryPoint())) + "\t" + from + "\t" + r.getReferenceType().getName() + "\t" + (fi != null ? 1 : 0));
            }
        }
        fw.close(); rw.close(); jw.close(); cw.close();

        PrintWriter mw = new PrintWriter(new FileWriter(outDir + "/mnemonics.tsv"));
        for (Map.Entry<String, Integer> e : mn.entrySet()) mw.println(e.getKey() + "\t" + e.getValue());
        mw.close();

        // Coverage of .text by function bodies, and what the rest is.
        PrintWriter vw = new PrintWriter(new FileWriter(outDir + "/coverage.txt"));
        MemoryBlock text = mem.getBlock(".text");
        AddressSet textSet = new AddressSet(text.getStart(), text.getEnd());
        AddressSet rest = textSet.subtract(covered);
        long restBytes = rest.getNumAddresses(), instrBytes = 0, dataBytes = 0, undefBytes = 0, padBytes = 0;
        int strayInstr = 0;
        PrintWriter sw = new PrintWriter(new FileWriter(outDir + "/stray.tsv"));
        for (AddressRange r : rest) {
            Address a = r.getMinAddress();
            while (a != null && a.compareTo(r.getMaxAddress()) <= 0) {
                CodeUnit cu = listing.getCodeUnitContaining(a);
                long len = 1;
                if (cu instanceof Instruction) {
                    instrBytes += cu.getLength(); len = cu.getLength(); strayInstr++;
                    sw.println(hx(rva(cu.getAddress())) + "\t" + cu.toString());
                } else if (cu instanceof Data && ((Data) cu).isDefined()) {
                    dataBytes += cu.getLength(); len = cu.getLength();
                } else {
                    undefBytes++;
                    int v = mem.getByte(a) & 0xFF;
                    if (v == 0xCC || v == 0x90 || v == 0x00) padBytes++;
                }
                if (cu != null && cu.getMinAddress().compareTo(a) < 0) len = cu.getMaxAddress().subtract(a) + 1;
                a = a.addNoWrap(Math.max(1, len));
                if (a.compareTo(r.getMaxAddress()) > 0) break;
            }
        }
        sw.close();
        vw.println("functions\t" + nf);
        vw.println("text_bytes\t" + textSet.getNumAddresses());
        vw.println("covered_bytes\t" + covered.intersect(textSet).getNumAddresses());
        vw.println("uncovered_bytes\t" + restBytes);
        vw.println("uncovered_instruction_bytes\t" + instrBytes + "\t(" + strayInstr + " instructions)");
        vw.println("uncovered_defined_data_bytes\t" + dataBytes);
        vw.println("uncovered_undefined_bytes\t" + undefBytes + "\tof which CC/90/00\t" + padBytes);
        vw.close();
        println("DumpRecompStats: " + nf + " functions written to " + outDir);
    }
}
