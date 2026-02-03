
Separation Logic Examples - Basic Operations:

  $ . ../utility.sh

  $ check test_basic.ml
      ref_create_true: true
        ref_read_true: true
       ref_write_true: true
     write_frame_true: true
           incr_true: true
     incr_frame_true: true
     incr_wrong_false: false (expected)
  frame_violated_false: false (expected)
  ALL OK!

Separation Logic Examples - Swap Operations:

  $ check test_swap.ml
  swap_distinct_true: true
    swap_frame_true: true
     self_swap_true: true
  swap_not_identity_false: false (expected)
  partial_swap_false: false (expected)
  ALL OK!
