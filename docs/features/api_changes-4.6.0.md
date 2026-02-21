API Changes

⚠️ Endpoint GET /api/roms now only accepts multiple values for the following fields:
platform_id -> platform_ids
selected_genre -> genres
selected_franchise -> franchises
selected_collection -> collections
selected_company -> companies
selected_age_rating -> age_ratings
selected_status -> statuses
selected_region -> regions
selected_language -> languages
The endpoint also accepts the following new fields:
last_played: Whether the rom has a last played value for the current user
player_counts: Associated player counts
genres_logic: Logic operator for genres filter: 'any' (OR) or 'all' (AND)
franchises_logic: Logic operator for franchises filter: 'any' (OR) or 'all' (AND)
collections_logic: Logic operator for collections filter: 'any' (OR) or 'all' (AND)
companies_logic: Logic operator for companies filter: 'any' (OR) or 'all' (AND)
age_ratings_logic: Logic operator for age ratings filter: 'any' (OR) or 'all' (AND)
regions_logic: Logic operator for regions filter: 'any' (OR) or 'all' (AND)
languages_logic: Logic operator for languages filter: 'any' (OR) or 'all' (AND)
statuses_logic: Logic operator for statuses filter: 'any' (OR) or 'all' (AND)
player_counts_logic: Logic operator for player count filter: 'any' (OR) or 'all' (AND)
New field UserSchema.ui_settings/UserForm.ui_settings: sync UI settings between devices
New field RomMetadataSchema.player_count: Aggregate player count for games (1, 2, 2-4, etc)
New field RomSchema.has_notes: Whether a ROM + user combo has at least 1 note
New field RomSchema.manual_metadata: Manually set metadata fields typically aggregated from metadata sources
New endpoint GET /api/setup/library: Get library structure information for setup wizard
New endpoint POST /api/setup/platforms: Create platform folders during setup wizard
Expose scan.media from config file via ConfigResponse.SCAN_MEDIA property
