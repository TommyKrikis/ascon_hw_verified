// ---------------------------------------------------------------------------
// ascon_scoreboard -- checks observed transactions against the NIST reference.
//
// Subscribes to the monitor's analysis port. Holds the EXPECTED half of the
// KAT database (kat_ct / kat_tag) and compares each observed transaction
// against the next vector in order.
//
// It never sees the stimulus files, and the sequence never sees these -- so
// neither side can bias the check.
// ---------------------------------------------------------------------------
class ascon_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ascon_scoreboard)

  // Receives ascon_sequence_item objects written by the monitor.
  uvm_analysis_imp #(ascon_sequence_item, ascon_scoreboard) mon_imp;

  localparam int NVEC_MAX = 1089;
  localparam int MAXBLK   = 3;

  logic [127:0] kat_ct  [0:MAXBLK*NVEC_MAX-1];
  logic [127:0] kat_tag [0:NVEC_MAX-1];

  int vec_idx  = 0;    // which KAT vector the next transaction should match
  int n_passed = 0;
  int n_failed = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_imp = new("mon_imp", this);
    $readmemh("kat_ct.hex",  kat_ct);
    $readmemh("kat_tag.hex", kat_tag);
  endfunction

  // -------------------------------------------------------------------------
  // write() is called by the monitor's analysis port. The name is fixed --
  // uvm_analysis_imp requires a method called exactly "write".
  // -------------------------------------------------------------------------
  virtual function void write(ascon_sequence_item tr);
    byte exp_ct[];
    bit  ok = 1;
    int  v  = vec_idx;

    if (v >= NVEC_MAX) begin
      `uvm_error(get_type_name(), "more transactions than KAT vectors")
      return;
    end

    // expected ciphertext: same byte count as the observed plaintext
    exp_ct = new[tr.ct.size()];
    for (int j = 0; j < exp_ct.size(); j++)
      exp_ct[j] = kat_ct[v*MAXBLK + j/16][(j%16)*8 +: 8];

    // ---- ciphertext ----
    foreach (tr.ct[j])
      if (tr.ct[j] !== exp_ct[j]) begin
        ok = 0;
        `uvm_error(get_type_name(),
          $sformatf("vec %0d ct[%0d]: got %02h exp %02h", v, j, tr.ct[j], exp_ct[j]))
      end

    // ---- tag ----
    if (tr.tag !== kat_tag[v]) begin
      ok = 0;
      `uvm_error(get_type_name(),
        $sformatf("vec %0d tag: got %032h exp %032h", v, tr.tag, kat_tag[v]))
    end

    if (ok) n_passed++; else n_failed++;
    vec_idx++;

    if ((vec_idx % 100) == 0)
      `uvm_info(get_type_name(),
        $sformatf("checked %0d vectors, %0d failed", vec_idx, n_failed), UVM_LOW)
  endfunction

  // -------------------------------------------------------------------------
  // report_phase runs after the run phase -- the place for a final verdict.
  // -------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("SCOREBOARD: %0d checked, %0d passed, %0d failed",
                vec_idx, n_passed, n_failed), UVM_LOW)
    if (vec_idx == 0)
      `uvm_error(get_type_name(), "scoreboard saw no transactions")
  endfunction

endclass
