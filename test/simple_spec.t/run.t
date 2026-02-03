
  $ . ../utility.sh

Simple separation logic specification tests - heap operations:

  $ check test_simple_heap.ml
       ref_create_true: true
         ref_read_true: true
        ref_write_true: true
            swap_true: false
        incr_ref_true: true
       ref_wrong_false: true
     ref_missing_false: true
  [1]

Simple separation logic specification tests - pure computations:

  $ check test_simple_pure.ml
            add_true: true
          const_true: true
             id_true: true
    is_positive_true: true
       fst_pair_true: true
      add_wrong_false: false (expected)
    const_wrong_false: false (expected)
  ALL OK!

