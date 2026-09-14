import 'package:flutter/cupertino.dart';

/// Preset icon keys stored in areas.icon. Not real Apple SF Symbol names --
/// see CLAUDE.md / the Areas Part 2 plan for why. Just a small vocabulary we
/// control, mapped to CupertinoIcons for rendering.
const areaIconKeys = [
  'kitchen',
  'bedroom',
  'bathroom',
  'living_room',
  'stairs',
  'door',
  'laundry',
  'other',
];

IconData areaIconFor(String? key) {
  switch (key) {
    case 'kitchen':
      return CupertinoIcons.house_fill;
    case 'bedroom':
      return CupertinoIcons.bed_double_fill;
    case 'bathroom':
      return CupertinoIcons.drop_fill;
    case 'living_room':
      return CupertinoIcons.tv_fill;
    case 'stairs':
      return CupertinoIcons.arrow_up_arrow_down;
    case 'door':
      return CupertinoIcons.square_arrow_right_fill;
    case 'laundry':
      return CupertinoIcons.square_stack_3d_up_fill;
    case 'other':
      return CupertinoIcons.square_grid_2x2_fill;
    default:
      return CupertinoIcons.house;
  }
}
