# API Refactor Ergebnisse

## Phase 1: Analyse
Stand: 2026-02-14

## Methodik
- Code-Scan über `romm/**/*.swift` mit Ausschluss von `romm/romm/Data/DataSources/API/OpenAPIs/**`.
- Erfasst wurden:
  - Verwendungen von API-Klassen und API-Methoden
  - Verwendungen von Model-Typen
  - Direkte und transitive Model-Abhängigkeiten
  - Nutzung/Notwendigkeit der Support-Dateien
- Hinweis: Der im Plan genannte Pfad `romm/romm/Data/DataSources/API/RommAPIClient.swift` ist veraltet. Tatsächlich liegt die Datei unter `romm/romm/Data/DataSources/RommAPIClient.swift`.

## Zusammenfassung
- API-Klassen: **9/16** verwendet
- API-Methoden (Endpunkt-Methoden): **21/81** verwendet
- Models direkt verwendet: **17/73**
- Models transitiv benötigt (Closure): **45/73**
- Models als sichere Löschkandidaten (nicht direkt + nicht transitiv): **28/73**
- Support-Dateien erforderlich: **12/12**

## Liste A: VERWENDET (behalten)

### API-Klassen
- [x] `AuthAPI.swift`
  - [x] `loginApiLoginPost()` (`romm/romm/Data/DataSources/RommAPIClient.swift:371`)
  - [x] `logoutApiLogoutPost()` (`romm/romm/Data/DataSources/RommAPIClient.swift:375`)

- [x] `UsersAPI.swift`
  - [x] `getCurrentUserApiUsersMeGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:382`)
  - [x] `getUsersApiUsersGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:386`)

- [x] `RomsAPI.swift`
  - [x] `getRomsApiRomsGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:398`, `romm/romm/Data/DataSources/RommAPIClient.swift:417`, `romm/romm/Data/DataSources/RommAPIClient.swift:452`)
  - [x] `getRomApiRomsIdGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:446`)
  - [x] `updateRomUserApiRomsIdPropsPut()` (`romm/romm/Data/DataSources/RommAPIClient.swift:472`)

- [x] `CollectionsAPI.swift`
  - [x] `getCollectionsApiCollectionsGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:584`)
  - [x] `getCollectionApiCollectionsIdGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:589`)
  - [x] `getVirtualCollectionsApiCollectionsVirtualGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:594`)
  - [x] `getVirtualCollectionApiCollectionsVirtualIdGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:599`)
  - [x] `addCollectionApiCollectionsPost()` (`romm/romm/Data/DataSources/RommAPIClient.swift:604`)
  - [x] `deleteCollectionApiCollectionsIdDelete()` (`romm/romm/Data/DataSources/RommAPIClient.swift:648`)
  - [x] `updateCollectionApiCollectionsIdPut()` (`romm/romm/Data/DataSources/RommAPIClient.swift:783`)

- [x] `PlatformsAPI.swift`
  - [x] `getPlatformsApiPlatformsGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:796`)
  - [x] `addPlatformApiPlatformsPost()` (`romm/romm/Data/DataSources/RommAPIClient.swift:805`)
  - [x] `deletePlatformApiPlatformsIdDelete()` (`romm/romm/Data/DataSources/RommAPIClient.swift:812`)

- [x] `SystemAPI.swift`
  - [x] `heartbeatApiHeartbeatGet()` (`romm/romm/Data/DataSources/RommAPIClient.swift:820`)

- [x] `StatsAPI.swift`
  - [x] `statsApiStatsGet()` (`romm/romm/Data/Repositories/StatsRepository.swift:22`)

- [x] `SavesAPI.swift`
  - [x] `getSavesApiSavesGet()` (`romm/romm/UI/RomDetail/RomDetailViewModel.swift:192`)

- [x] `StatesAPI.swift`
  - [x] `getStatesApiStatesGet()` (`romm/romm/UI/RomDetail/RomDetailViewModel.swift:208`)

### Models (direkt verwendet)
- [x] `BodyAddPlatformApiPlatformsPost.swift` (`romm/romm/Data/DataSources/RommAPIClient.swift:804`)
- [x] `BodyUpdateRomUserApiRomsIdPropsPut.swift` (`romm/romm/Data/DataSources/RommAPIClient.swift:467`)
- [x] `CollectionSchema.swift` (`romm/romm/Data/Mappers/CollectionMapper.swift:22`)
- [x] `CustomLimitOffsetPageSimpleRomSchema.swift` (`romm/romm/Data/DataSources/RommAPIClient.swift:31`)
- [x] `DetailedRomSchema.swift` (`romm/romm/Data/Mappers/RomMapper.swift:79`)
- [x] `HeartbeatResponse.swift` (`romm/romm/Data/DataSources/RommAPIClient.swift:63`)
- [x] `IGDBAgeRating.swift` (`romm/romm/Data/Mappers/RomMapper.swift:205`)
- [x] `PlatformSchema.swift` (`romm/romm/Data/Mappers/PlatformMapper.swift:11`)
- [x] `RomFileSchema.swift` (`romm/romm/UI/Devices/SFTP/SFTPUploadViewModel.swift:30`)
- [x] `RomUserSchema.swift` (`romm/romm/Data/DataSources/RommAPIClient.swift:464`)
- [x] `SaveSchema.swift` (`romm/romm/UI/RomDetail/RomDetailViewModel.swift:25`)
- [x] `ScreenshotSchema.swift` (`romm/romm/UI/RomDetail/RomDetailView.swift:1254`)
- [x] `SimpleRomSchema.swift` (`romm/romm/Data/Mappers/RomMapper.swift:11`)
- [x] `StateSchema.swift` (`romm/romm/UI/RomDetail/RomDetailViewModel.swift:26`)
- [x] `StatsReturn.swift` (`romm/romm/Data/Mappers/StatsMapper.swift:11`)
- [x] `UserSchema.swift` (`romm/romm/Data/Mappers/UserMapper.swift:11`)
- [x] `VirtualCollectionSchema.swift` (`romm/romm/Data/Mappers/CollectionMapper.swift:41`)

### Support-Dateien (erforderlich)
- [x] `APIs.swift` (enthält `rommAPI`, `RequestBuilder`; direkt genutzt in `romm/romm/Data/DataSources/RommAPIClient.swift:154`)
- [x] `URLSessionImplementations.swift` (liefert `HTTPMethod`, direkt genutzt in `romm/romm/Data/DataSources/RommAPIClient.swift:12`)
- [x] `Models.swift` (Basis-Typen wie `Response`, `ErrorResponse` für Builder/Transport-Layer)
- [x] `Configuration.swift` (Statuscode-Handling über Extensions)
- [x] `APIHelper.swift` (Pfad-/Query-/Header-Helfer für API-Dateien)
- [x] `CodableHelper.swift` (Decode/Encode für OpenAPI-Transport)
- [x] `JSONDataEncoding.swift` (Request-Encoding)
- [x] `JSONEncodingHelper.swift` (Body-Encoding für API-Methoden)
- [x] `Extensions.swift` (`encodeToJSON()`, Response-Helfer)
- [x] `Validation.swift` (wird in mehreren benötigten Models genutzt)
- [x] `OpenISO8601DateFormatter.swift` (Datumsformatierung über `CodableHelper`)
- [x] `SynchronizedDictionary.swift` (Thread-sichere Stores im URLSession-Builder)

## Liste B: NICHT VERWENDET (entfernen)

### API-Klassen (komplett ungenutzt)
- [x] `ConfigAPI.swift`
- [x] `FeedsAPI.swift`
- [x] `FirmwareAPI.swift`
- [x] `RawAPI.swift`
- [x] `ScreenshotsAPI.swift`
- [x] `SearchAPI.swift`
- [x] `TasksAPI.swift`

### API-Methoden (teilweise ungenutzt)
- [x] `AuthAPI.swift`
  - [x] `authOpenidApiOauthOpenidGet()`
  - [x] `loginViaOpenidApiLoginOpenidGet()`
  - [x] `requestPasswordResetApiForgotPasswordPost()`
  - [x] `resetPasswordApiResetPasswordPost()`
  - [x] `tokenApiTokenPost()`

- [x] `CollectionsAPI.swift`
  - [x] `addSmartCollectionApiCollectionsSmartPost()`
  - [x] `deleteSmartCollectionApiCollectionsSmartIdDelete()`
  - [x] `getSmartCollectionApiCollectionsSmartIdGet()`
  - [x] `getSmartCollectionsApiCollectionsSmartGet()`
  - [x] `updateSmartCollectionApiCollectionsSmartIdPut()`

- [x] `PlatformsAPI.swift`
  - [x] `getPlatformApiPlatformsIdGet()`
  - [x] `getSupportedPlatformsApiPlatformsSupportedGet()`
  - [x] `updatePlatformApiPlatformsIdPut()`

- [x] `RomsAPI.swift`
  - [x] `addRomApiRomsPost()`
  - [x] `addRomManualsApiRomsIdManualsPost()`
  - [x] `deleteRomsApiRomsDeletePost()`
  - [x] `getRomContentApiRomsIdContentFileNameGet()`
  - [x] `getRomfileApiRomsfilesIdGet()`
  - [x] `getRomfileContentApiRomsfilesIdContentFileNameGet()`
  - [x] `headRomContentApiRomsIdContentFileNameHead()`
  - [x] `updateRomApiRomsIdPut()`

- [x] `SavesAPI.swift`
  - [x] `addSaveApiSavesPost()`
  - [x] `deleteSavesApiSavesDeletePost()`
  - [x] `getSaveApiSavesIdGet()`
  - [x] `updateSaveApiSavesIdPut()`

- [x] `StatesAPI.swift`
  - [x] `addStateApiStatesPost()`
  - [x] `deleteStatesApiStatesDeletePost()`
  - [x] `getStateApiStatesIdGet()`
  - [x] `updateStateApiStatesIdPut()`

- [x] `UsersAPI.swift`
  - [x] `addUserApiUsersPost()`
  - [x] `createInviteLinkApiUsersInviteLinkPost()`
  - [x] `createUserFromInviteApiUsersRegisterPost()`
  - [x] `deleteUserApiUsersIdDelete()`
  - [x] `getUserApiUsersIdGet()`
  - [x] `refreshRetroAchievementsApiUsersIdRaRefreshPost()`
  - [x] `updateUserApiUsersIdPut()`

### Models

#### Direkt ungenutzt, aber transitiv benötigt (noch NICHT entfernen)
- [ ] `EarnedAchievement.swift`
- [ ] `EmulationDict.swift`
- [ ] `FilesystemDict.swift`
- [ ] `FirmwareSchema.swift`
- [ ] `FrontendDict.swift`
- [ ] `IGDBMetadataPlatform.swift`
- [ ] `IGDBRelatedGame.swift`
- [ ] `LaunchboxImage.swift`
- [ ] `MetadataSourcesDict.swift`
- [ ] `MobyMetadataPlatform.swift`
- [ ] `OIDCDict.swift`
- [ ] `RAGameRomAchievement.swift`
- [ ] `RAProgression.swift`
- [ ] `RAUserGameProgression.swift`
- [ ] `Role.swift`
- [ ] `RomFileCategory.swift`
- [ ] `RomHasheousMetadata.swift`
- [ ] `RomIGDBMetadata.swift`
- [ ] `RomLaunchboxMetadata.swift`
- [ ] `RomMetadataSchema.swift`
- [ ] `RomMobyMetadata.swift`
- [ ] `RomRAMetadata.swift`
- [ ] `RomSSMetadata.swift`
- [ ] `RomUserStatus.swift`
- [ ] `SiblingRomSchema.swift`
- [ ] `SystemDict.swift`
- [ ] `UserCollectionSchema.swift`
- [ ] `UserNotesSchema.swift`

#### Entfernen-Kandidaten (nicht direkt + nicht transitiv benötigt)
- [x] `AddFirmwareResponse.swift`
- [x] `BodyAddUserApiUsersPost.swift`
- [x] `BodyCreateUserFromInviteApiUsersRegisterPost.swift`
- [x] `BodyDeleteRomsApiRomsDeletePost.swift`
- [x] `BodyRequestPasswordResetApiForgotPasswordPost.swift`
- [x] `BodyResetPasswordApiResetPasswordPost.swift`
- [x] `BodyUpdatePlatformApiPlatformsIdPut.swift`
- [x] `BulkOperationResponse.swift`
- [x] `ConfigResponse.swift`
- [x] `HTTPValidationError.swift`
- [x] `InviteLinkSchema.swift`
- [x] `JobStatus.swift`
- [x] `SearchCoverSchema.swift`
- [x] `SearchRomSchema.swift`
- [x] `SmartCollectionSchema.swift`
- [x] `TaskExecutionResponse.swift`
- [x] `TaskInfo.swift`
- [x] `TaskStatusResponse.swift`
- [x] `TinfoilFeedFileSchema.swift`
- [x] `TinfoilFeedSchema.swift`
- [x] `TinfoilFeedTitleDBSchema.swift`
- [x] `TokenResponse.swift`
- [x] `ValidationError.swift`
- [x] `ValidationErrorLocInner.swift`
- [x] `WebrcadeFeedCategorySchema.swift`
- [x] `WebrcadeFeedItemPropsSchema.swift`
- [x] `WebrcadeFeedItemSchema.swift`
- [x] `WebrcadeFeedSchema.swift`

## Abhängigkeitsanalyse (Auszug)
- `CustomLimitOffsetPageSimpleRomSchema -> SimpleRomSchema`
- `SimpleRomSchema -> RomFileSchema, RomUserSchema, SiblingRomSchema, RomHasheousMetadata, RomIGDBMetadata, RomLaunchboxMetadata, RomMetadataSchema, RomMobyMetadata, RomSSMetadata`
- `DetailedRomSchema -> RomFileSchema, RomUserSchema, SaveSchema, StateSchema, ScreenshotSchema, SiblingRomSchema, UserCollectionSchema, UserNotesSchema, RomHasheousMetadata, RomIGDBMetadata, RomLaunchboxMetadata, RomMetadataSchema, RomMobyMetadata, RomRAMetadata, RomSSMetadata`
- `HeartbeatResponse -> SystemDict, MetadataSourcesDict, FilesystemDict, EmulationDict, FrontendDict, OIDCDict`
- `UserSchema -> RAProgression -> RAUserGameProgression -> EarnedAchievement`
- `PlatformSchema -> FirmwareSchema`
- `RomUserSchema -> RomUserStatus`
- `RomFileSchema -> RomFileCategory`

## Empfehlungen (sicheres Vorgehen)
1. Entferne zuerst die **7 komplett ungenutzten API-Klassen**.
2. Entferne danach die **28 Model-Entfernen-Kandidaten** (nicht transitiv benötigt).
3. Build + Smoke-Test nach jedem Block (Auth, ROM-Liste/Detail, Collections, Platforms, Heartbeat).
4. Danach optional: ungenutzte Methoden in teilweise genutzten API-Klassen reduzieren.
5. Direkte OpenAPI-Aufrufe außerhalb `RommAPIClient` abbauen (`StatsRepository`, `RomDetailViewModel`) und zentralisieren.
