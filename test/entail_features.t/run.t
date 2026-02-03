Tests for new entailment features

  $ . ../utility.sh

Reset entailment tests:
  $ check test_reset.ml
            reset_pure: error
             reset_add: error
          reset_nested: error
             reset_let: error
     reset_wrong_false: error
  ALL OK!

Shift entailment tests:
  $ check test_shift.ml
           shift_basic: error
           shift_abort: error
        shift_identity: error
          shift0_basic: error
     shift_wrong_false: error
  ALL OK!

Effect entailment tests:
  $ check test_effects.ml
  File "_none_", line 6, characters 10-17:
  Error: Unbound value "perform"

  ALL OK!

Disjunction tests (verifies bug fix):
  $ check test_disjunction.ml
           disj_simple: error
          disj_subsume: error
             disj_heap: error
           disj_nested: error
  disj_in...lete_false: error
  ALL OK!

Heap entailment tests:
  $ check test_heap.ml
            heap_basic: error
             heap_read: error
           heap_update: error
              heap_two: error
            heap_frame: error
          heap_precond: error
   heap_update_precond: error
      heap_wrong_false: error
    heap_missing_false: error
  ALL OK!
