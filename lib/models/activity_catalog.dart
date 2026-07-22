class ActivityCatalogItem {
  final String id;
  final String nameKey;
  final double met;

  const ActivityCatalogItem({
    required this.id,
    required this.nameKey,
    required this.met,
  });
}

const activityCatalog = <ActivityCatalogItem>[
  ActivityCatalogItem(
    id: 'abdominals',
    nameKey: 'activity_name_abdominals',
    met: 4.0,
  ),
  ActivityCatalogItem(
    id: 'aerobics',
    nameKey: 'activity_name_aerobics',
    met: 7.3,
  ),
  ActivityCatalogItem(
    id: 'squat',
    nameKey: 'activity_name_squat',
    met: 5.0,
  ),
  ActivityCatalogItem(
    id: 'aikido',
    nameKey: 'activity_name_aikido',
    met: 10.3,
  ),
  ActivityCatalogItem(
    id: 'stretching',
    nameKey: 'activity_name_stretching',
    met: 2.3,
  ),
  ActivityCatalogItem(
    id: 'masonry',
    nameKey: 'activity_name_masonry',
    met: 4.8,
  ),
  ActivityCatalogItem(
    id: 'aquagym',
    nameKey: 'activity_name_aquagym',
    met: 5.5,
  ),
  ActivityCatalogItem(
    id: 'archery',
    nameKey: 'activity_name_archery',
    met: 3.5,
  ),
  ActivityCatalogItem(
    id: 'badminton',
    nameKey: 'activity_name_badminton',
    met: 7.0,
  ),
  ActivityCatalogItem(
    id: 'pull_ups',
    nameKey: 'activity_name_pull_ups',
    met: 8.0,
  ),
  ActivityCatalogItem(
    id: 'basketball',
    nameKey: 'activity_name_basketball',
    met: 8.0,
  ),
  ActivityCatalogItem(
    id: 'baseball',
    nameKey: 'activity_name_baseball',
    met: 5.0,
  ),
  ActivityCatalogItem(
    id: 'walking',
    nameKey: 'activity_name_walking',
    met: 3.8,
  ),
  ActivityCatalogItem(
    id: 'running',
    nameKey: 'activity_name_running',
    met: 9.8,
  ),
  ActivityCatalogItem(
    id: 'cycling',
    nameKey: 'activity_name_cycling',
    met: 7.5,
  ),
  ActivityCatalogItem(
    id: 'swimming',
    nameKey: 'activity_name_swimming',
    met: 8.0,
  ),
  ActivityCatalogItem(
    id: 'weight_training',
    nameKey: 'activity_name_weight_training',
    met: 6.0,
  ),
  ActivityCatalogItem(
    id: 'football',
    nameKey: 'activity_name_football',
    met: 7.0,
  ),
  ActivityCatalogItem(
    id: 'yoga',
    nameKey: 'activity_name_yoga',
    met: 2.8,
  ),
  ActivityCatalogItem(
    id: 'pilates',
    nameKey: 'activity_name_pilates',
    met: 3.0,
  ),
  ActivityCatalogItem(
    id: 'dance',
    nameKey: 'activity_name_dance',
    met: 6.5,
  ),
  ActivityCatalogItem(
    id: 'boxing',
    nameKey: 'activity_name_boxing',
    met: 9.0,
  ),
  ActivityCatalogItem(
    id: 'crossfit',
    nameKey: 'activity_name_crossfit',
    met: 8.0,
  ),
  ActivityCatalogItem(
    id: 'elliptical',
    nameKey: 'activity_name_elliptical',
    met: 5.0,
  ),
  ActivityCatalogItem(
    id: 'rowing',
    nameKey: 'activity_name_rowing',
    met: 7.0,
  ),
  ActivityCatalogItem(
    id: 'jump_rope',
    nameKey: 'activity_name_jump_rope',
    met: 11.0,
  ),
];
