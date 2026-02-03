
Reynolds Separation Logic Paper Examples - Basic Operations:

  $ . ../utility.sh

  $ check test_basic_ops.ml
   mutation_local_true: true
   mutation_param_true: true
      alloc_local_true: true
       alloc_expr_true: true
     lookup_local_true: true
  lookup_preserves_true: true
  read_modify_write_true: true
        increment_true: true
        decrement_true: true
  mutation_wrong_false: true
     alloc_wrong_false: true
    lookup_wrong_false: false (expected)
  increment_wrong_false: true
  [1]

Reynolds Separation Logic Paper Examples - Frame Rule:

  $ check test_frame_rule.ml
   mutation_frame_true: true
  mutation_preserves_other_true: true
      alloc_frame_true: true
   alloc_preserve_true: true
     lookup_frame_true: true
  read_preserves_other_true: true
             swap_true: true
  swap_with_frame_true: true
  incr_with_frame_true: true
      double_incr_true: true
       copy_value_true: true
     triple_first_true: true
    triple_middle_true: true
   sum_into_first_true: true
  frame_violated_false: true
      swap_wrong_false: true
   missing_frame_false: true
  [1]

Reynolds Separation Logic Paper Examples - Separating Conjunction:

  $ check test_sep_conj.ml
         two_refs_true: true
  sep_commutative_true: true
     alloc_single_true: true
  pure_computation_true: true
  disjoint_writes_true: true
   disjoint_reads_true: false
       three_refs_true: true
        four_refs_true: true
     modify_first_true: true
    modify_second_true: true
      modify_both_true: true
  pure_and_spatial_true: false
  pure_result_with_heap_true: false
  create_two_refs_true: true
   alloc_disjoint_true: true
        sum_three_true: false
     rotate_three_true: true
    aliasing_test_true: true
     missing_sep_false: true
       wrong_sep_false: true
  [1]

Reynolds Separation Logic Paper Examples - Cons Cells:

  $ check test_cons_cells.ml
        make_cons_true: true
        read_head_true: true
         set_head_true: true
        two_cells_true: true
   read_two_cells_true: false
       swap_cells_true: true
     cell_extract_true: true
  process_adjacent_true: true
     copy_forward_true: true
  create_two_cells_true: true
     reverse_step_true: true
  create_tree_node_true: true
    read_children_true: false
  cell_read_wrong_false: false (expected)
    missing_cell_false: true
      swap_wrong_false: true
  [1]

Reynolds Separation Logic Paper Examples - Records (placeholder):

  $ check test_records.ml
     placeholder_true: true

Reynolds Separation Logic Paper Examples - DLL (placeholder):

  $ check test_dll.ml
     placeholder_true: true

Reynolds Separation Logic Paper Examples - DLL Entailment:

  $ check test_dll_entail.ml
  single_node_frame_true: true
       update_next_true: true
       update_prev_true: true
       link_nodes_true: true
     unlink_nodes_true: true
  swap_node_values_true: true
  dll_link_pattern_true: true
  dll_insert_pattern_true: true
  link_incomplete_false: true
      swap_wrong_false: true
  [1]

