// Read-only export of what Hoi3Recomp's lifter reads, from the Ghidra project.
// Writes program.txt, functions.tsv, jumptables.tsv and addresstaken.tsv into the folder
// given as the first script argument. Changes nothing in the program; run with -readOnly.
// Driven by Hoi3Recomp's tools/Export-LifterInput.ps1. Addresses are rvas.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;

public class ExportRecompInput extends GhidraScript {

    long rva(Address a) { return a.getOffset() - currentProgram.getImageBase().getOffset(); }

    String hx(long v) { return "0x" + Long.toHexString(v).toUpperCase(); }

    // Ghidra makes the compiler's exception funclets functions of their own; the lifter
    // treats them differently from ordinary code, so each entry says which it is.
    String kindOf(Function f) {
        String n = f.getName();
        if (n.startsWith("Unwind@")) return "unwind";
        if (n.startsWith("Catch")) return "catch";
        if (f.isThunk()) return "thunk";
        return "code";
    }

    @Override
    public void run() throws Exception {
        String outDir = getScriptArgs()[0];
        new File(outDir).mkdirs();
        Listing listing = currentProgram.getListing();
        FunctionManager fm = currentProgram.getFunctionManager();
        ReferenceManager rm = currentProgram.getReferenceManager();

        PrintWriter fw = new PrintWriter(new FileWriter(outDir + "/functions.tsv"));
        PrintWriter jw = new PrintWriter(new FileWriter(outDir + "/jumptables.tsv"));
        PrintWriter aw = new PrintWriter(new FileWriter(outDir + "/addresstaken.tsv"));
        fw.println("entry\tkind\tname\tranges\tthunk_target");
        jw.println("at\tfunction\tstate\ttargets");
        aw.println("entry\tfrom_data\tfrom_code_operand");

        int functions = 0, tables = 0, unresolved = 0, taken = 0;
        for (Function f : fm.getFunctions(true)) {
            if (monitor.isCancelled()) break;
            functions++;
            long entry = rva(f.getEntryPoint());

            StringBuilder ranges = new StringBuilder();
            for (AddressRange r : f.getBody()) {
                if (ranges.length() > 0) ranges.append(';');
                ranges.append(hx(rva(r.getMinAddress()))).append('-').append(hx(rva(r.getMaxAddress())));
            }
            String target = "";
            if (f.isThunk()) {
                Function t = f.getThunkedFunction(false);
                if (t != null) target = t.isExternal() ? "EXT:" + t.getName(true) : hx(rva(t.getEntryPoint()));
            }
            fw.println(hx(entry) + "\t" + kindOf(f) + "\t" + f.getName(true) + "\t" + ranges + "\t" + target);

            // Every computed jump: the targets Ghidra resolved for it, or "unresolved".
            for (Instruction in : listing.getInstructions(f.getBody(), true)) {
                FlowType ft = in.getFlowType();
                if (!(ft.isComputed() && ft.isJump())) continue;
                List<String> targets = new ArrayList<>();
                boolean external = false;
                for (Reference r : in.getReferencesFrom()) {
                    if (r.getToAddress().isExternalAddress()) external = true;
                    else if (r.getReferenceType().isFlow()) targets.add(hx(rva(r.getToAddress())));
                }
                String state = external ? "import" : (targets.isEmpty() ? "unresolved" : "table");
                if (state.equals("table")) tables++;
                if (state.equals("unresolved")) unresolved++;
                jw.println(hx(rva(in.getAddress())) + "\t" + hx(entry) + "\t" + state + "\t" + String.join(",", targets));
            }

            // Whether the entry's address is held anywhere other than a direct call: from
            // data (a virtual table, a table of pointers) or as an operand in code.
            int fromData = 0, fromOperand = 0;
            for (Reference r : rm.getReferencesTo(f.getEntryPoint())) {
                Instruction from = listing.getInstructionAt(r.getFromAddress());
                if (from == null) fromData++;
                else if (r.getReferenceType().isData()) fromOperand++;
            }
            if (fromData + fromOperand > 0) {
                taken++;
                aw.println(hx(entry) + "\t" + fromData + "\t" + fromOperand);
            }
        }
        fw.close();
        jw.close();
        aw.close();

        PrintWriter pw = new PrintWriter(new FileWriter(outDir + "/program.txt"));
        pw.println("program\t" + currentProgram.getName());
        pw.println("sha256\t" + currentProgram.getExecutableSHA256());
        pw.println("image_base\t" + hx(currentProgram.getImageBase().getOffset()));
        pw.println("exported\t" + new SimpleDateFormat("yyyy-MM-dd HH:mm").format(new Date()));
        pw.println("functions\t" + functions);
        pw.println("jump_tables\t" + tables);
        pw.println("unresolved_jumps\t" + unresolved);
        pw.println("address_taken\t" + taken);
        pw.close();

        println("ExportRecompInput: done, " + functions + " functions to " + outDir);
    }
}
