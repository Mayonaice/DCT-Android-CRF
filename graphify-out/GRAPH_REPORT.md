# Graph Report - crf_android_fresh  (2026-07-23)

## Corpus Check
- 103 files · ~324,706 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1438 nodes · 1735 edges · 42 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 54 edges
2. `../services/auth_service.dart` - 30 edges
3. `package:flutter/services.dart` - 29 edges
4. `dart:async` - 28 edges
5. `../widgets/custom_modals.dart` - 28 edges
6. `../utils/orientation_lock.dart` - 25 edges
7. `../services/profile_service.dart` - 16 edges
8. `package:intl/intl.dart` - 15 edges
9. `package:flutter/foundation.dart` - 14 edges
10. `dart:convert` - 14 edges

## Surprising Connections (you probably didn't know these)
- `RegisterPlugins()` --calls--> `OnCreate()`  [INFERRED]
  windows\flutter\generated_plugin_registrant.cc → windows\runner\flutter_window.cpp
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\win32_window.cpp
- `dispose` --calls--> `my_application_dispose()`  [INFERRED]
  lib\widgets\tl_supervisor_dialog.dart → linux\my_application.cc

## Communities

### Community 0 - "Community 0"
Cohesion: 0.02
Nodes (121): Align, _applyScannedValueToField, _areAllCatridgeItemsValid, BoxDecoration, build, _buildApprovalField, _buildApprovalForm, _buildCatridgeSection (+113 more)

### Community 1 - "Community 1"
Cohesion: 0.02
Nodes (110): auth_service.dart, build, _buildFunctionCard, _buildMainMenuButton, _buildSmallMenuButton, _buildStatusBox, Color, Container (+102 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (99): apiCall, AutoLogoutMixin, startPeriodicTokenCheck, build, _denomValue, dispose, Exception, _formatCurrency (+91 more)

### Community 3 - "Community 3"
Cohesion: 0.02
Nodes (97): _activateCatridgeFisikManualMode, AlertDialog, Align, BoxConstraints, build, _buildDropdownField, _buildDropdownFieldForBagCode, _buildDropdownFieldForSealCode (+89 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (78): build, _buildDataCard, _buildLabelValue, Container, _isApprovedKonsolRow, KonsolClosingApprovalSummaryPage, _KonsolClosingApprovalSummaryPageState, Padding (+70 more)

### Community 5 - "Community 5"
Cohesion: 0.03
Nodes (59): build, CrfApp, _CrfAppState, CrfSplashScreen, _CrfSplashScreenState, Exception, ForceLandscapeWrapper, _getLoginWidget (+51 more)

### Community 6 - "Community 6"
Cohesion: 0.03
Nodes (60): AlertDialog, Align, build, _buildApprovalSection, _buildBody, _buildCatridgeField, _buildCatridgeSection, _buildDetailRow (+52 more)

### Community 7 - "Community 7"
Cohesion: 0.03
Nodes (56): AppAssets, AppColors, AppRoutes, AppTextStyles, AlertDialog, BarcodeScannerWidget, _BarcodeScannerWidgetState, build (+48 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (48): AddClosingDialog, _AddClosingDialogState, build, _buildDenomBox, _buildDetailRow, _buildDetailSection, _buildTableCell, _buildTableHeaderCell (+40 more)

### Community 9 - "Community 9"
Cohesion: 0.04
Nodes (49): build, _buildDenomEditField, _buildEditSection, _buildFooter, _buildHeader, _buildInfoSection, _buildOriginalDenomRow, _buildTitleSection (+41 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (41): build, _buildBottomContent, _buildNavButton, _buildTopNavigationBar, Container, _copyAndroidId, DeviceInfoScreen, _DeviceInfoScreenState (+33 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (42): AlertDialog, Align, build, _buildCartridgeField, _buildCartridgeSection, _buildCartridgeTotal, _buildDetailWSID, _buildLabelValue (+34 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (37): build, _buildOptionButton, _goToLogin, initState, LoginOptionPage, _LoginOptionPageState, Scaffold, SizedBox (+29 more)

### Community 13 - "Community 13"
Cohesion: 0.05
Nodes (35): _addToRecentScans, AlertDialog, build, DateTime, dispose, Divider, Exception, _formatTimeDiff (+27 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (36): Align, build, _buildBottomSections, _buildDataKonsolSection, _buildDataTable, _buildDateField, _buildDateRangeAndSearchSection, _buildDateRangeSection (+28 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (34): add_pengurangan_dialog.dart, AddPenguranganDialog, Align, build, _buildBottomSection, _buildDataTable, _buildDateField, _buildFilterSection (+26 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (34): Align, build, _buildBottomSection, _buildDataTable, _buildDateField, _buildDenominationField, _buildFilterSection, _buildFooter (+26 more)

### Community 17 - "Community 17"
Cohesion: 0.06
Nodes (34): Align, build, _buildAtmDataItem, _buildClosingForm, _buildDenomGrid, _buildDenomHeader, _buildDenomItem, _buildDetailRow (+26 more)

### Community 18 - "Community 18"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (33): Align, build, _buildDataRow, _buildDataRowInline, _buildDataRowLarge, _buildHeader, _buildHistoryItem, _buildHistoryList (+25 more)

### Community 20 - "Community 20"
Cohesion: 0.06
Nodes (31): Align, build, _buildBottomSection, _buildDataTable, _buildDateField, _buildFilterSection, _buildFooter, _buildHeader (+23 more)

### Community 21 - "Community 21"
Cohesion: 0.07
Nodes (25): AlertDialog, build, dispose, Function, Icon, initState, _onQRDetected, QRCodeScannerTLWidget (+17 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (23): BarcodeScannerWidget, _BarcodeScannerWidgetState, build, didChangeAppLifecycleState, didChangeMetrics, dispose, Function, initState (+15 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (21): ApiResponse, ATMPrepareReplenishData, CatridgeData, CatridgeDetail, CatridgeResponse, DetailCatridgeItem, parseBool, parseTotal (+13 more)

### Community 24 - "Community 24"
Cohesion: 0.1
Nodes (14): build, Dialog, dispose, Function, Icon, SizedBox, TLSupervisorDialog, _TLSupervisorDialogState (+6 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (18): build, _buildBottomContent, _buildNavButton, _buildTopNavigationBar, Container, didChangeAppLifecycleState, didChangeMetrics, dispose (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.13
Nodes (14): CatridgeReplenishData, CatridgeReplenishResponse, DetailReturnItem, _parseBool, ReturnCatridgeData, ReturnCatridgeResponse, ReturnCatridgeValidationResponse, ReturnDataFromView (+6 more)

### Community 27 - "Community 27"
Cohesion: 0.14
Nodes (13): close, createFixedSize, getInputTensor, getOutputTensor, Interpreter, loadArray, run, runInference (+5 more)

### Community 28 - "Community 28"
Cohesion: 0.17
Nodes (1): MainActivity

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 30 - "Community 30"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 31 - "Community 31"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 32 - "Community 32"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 33 - "Community 33"
Cohesion: 0.4
Nodes (4): ClosingAndroidRequest, ClosingAndroidResponse, ClosingPreviewItem, parseInt

### Community 34 - "Community 34"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 35 - "Community 35"
Cohesion: 0.5
Nodes (3): HistoryItem, HistoryRequest, HistoryResponse

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (2): PenguranganInsertRequest, PenguranganInsertResponse

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (1): Bank

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (1): PenguranganData

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (1): ReturnData

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (1): UpdateQtyCatridgeRequest

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (1): User

## Knowledge Gaps
- **1225 isolated node(s):** `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `SafePrefs`, `CrfSplashScreen`, `_CrfSplashScreenState` (+1220 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 28`** (12 nodes): `MainActivity.kt`, `MainActivity.kt`, `MainActivity`, `.applyOrientation()`, `.configureFlutterEngine()`, `.enforce()`, `.onConfigurationChanged()`, `.onCreate()`, `.onResume()`, `.onStart()`, `.onWindowFocusChanged()`, `.setRequestedOrientation()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (6 nodes): `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (5 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (3 nodes): `PenguranganInsertRequest`, `PenguranganInsertResponse`, `pengurangan_insert_request.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `Bank`, `bank_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `PenguranganData`, `pengurangan_data_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (2 nodes): `ReturnData`, `return_data_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (2 nodes): `UpdateQtyCatridgeRequest`, `update_qty_catridge_request.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (2 nodes): `User`, `user_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 7` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `Community 25`?**
  _High betweenness centrality (0.304) - this node is a cross-community bridge._
- **Why does `dart:async` connect `Community 1` to `Community 0`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 25`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `package:flutter/services.dart` connect `Community 10` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 25`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `SafePrefs` to the rest of the system?**
  _1225 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._