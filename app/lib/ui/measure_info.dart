import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

class MeasureInfo {
  const MeasureInfo(this.icon, this.how, {this.core = false});

  final IconData icon;
  final String how;

  /// Shown first; most size charts use these.
  final bool core;
}

const measureInfo = <Measure, MeasureInfo>{
  Measure.chest: MeasureInfo(
    Icons.accessibility_new,
    'Wrap the tape around the fullest part of your chest (bust), under your '
    'arms and across your shoulder blades. Keep it level and snug but not '
    'tight, and breathe out normally.',
    core: true,
  ),
  Measure.waist: MeasureInfo(
    Icons.straighten,
    'For trousers and jeans, measure around where the waistband usually sits. '
    'For tops and dresses, measure the narrowest part of your torso, usually '
    'just above the belly button. Do not pull your stomach in.',
    core: true,
  ),
  Measure.hip: MeasureInfo(
    Icons.airline_seat_legroom_normal,
    'Stand with your feet together and measure around the fullest part of '
    'your hips and seat.',
    core: true,
  ),
  Measure.height: MeasureInfo(
    Icons.height,
    'Without shoes, standing straight with your back against a wall.',
    core: true,
  ),
  Measure.shoulder: MeasureInfo(
    Icons.open_in_full,
    'Across your back, from the tip of one shoulder bone to the other. '
    'Easier with someone helping.',
  ),
  Measure.neck: MeasureInfo(
    Icons.circle_outlined,
    'Around the base of your neck, where a shirt collar sits. Keep one '
    'finger under the tape.',
  ),
  Measure.sleeve: MeasureInfo(
    Icons.back_hand_outlined,
    'From the tip of your shoulder, down the outside of a slightly bent arm, '
    'to the wrist bone.',
  ),
  Measure.inseam: MeasureInfo(
    Icons.swap_vert,
    'From the crotch down the inside of your leg to the ankle bone. Easiest '
    'way: lay a pair of trousers that fit you well flat and measure the '
    'inside seam.',
  ),
  Measure.foot: MeasureInfo(
    Icons.do_not_step,
    'Stand on a sheet of paper, mark the back of your heel and the tip of '
    'your longest toe, and measure between the marks. Do both feet, in the '
    'evening, and use the longer one.',
  ),
};

const measuringTips = [
  'Use a soft tailor\'s tape. No tape? Use a string, then lay it on a ruler.',
  'Measure over thin clothing or none at all.',
  'Keep the tape level and snug, not tight.',
  'Measure twice. If the numbers differ, use the larger one.',
];
