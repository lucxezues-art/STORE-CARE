// StockCare - Food Batch and Expiry Monitoring System
// Educational prototype for a scenario named SIERRA TRADING COMPANY.
// The organization name is used as the user's chosen project scenario; this prototype
// does not claim to verify the company's legal registration or represent a real deployment.
// Security logs record event metadata, not the full raw input supplied by a user.
//
// HOW TO STUDY THIS PROGRAM:
// 1. Start at main() near the bottom: it controls the menu and program flow.
// 2. Read StockCare: it contains the inventory rules and business logic.
// 3. Read StockBatch and StockMovement: they describe the data the program stores.
// 4. Read the read... functions: they ask for input and validate it.
// 5. Run the program and compare these comments with what you see on screen.
//
// KEY VOCABULARY:
// - Class: a blueprint for creating objects.
// - Object: one instance created from a class.
// - Method: a function that belongs to a class.
// - Parameter: information passed into a function.
// - Return value: information a function gives back.
// - Validation: checking data before accepting or using it.
// - Persistence: saving data so it remains after the program closes.
// - Audit log: a record of important events for later review.
// - FEFO: First Expired, First Out; use eligible stock with the earliest expiry first.
// - JSON: a text format used here to save structured data in files.
// - Exception: an error signal that can be caught and handled.
// - RegExp: a pattern used to check whether text follows an expected format.

import 'dart:convert';
import 'dart:io';

const dataDirectory = 'stockcare_data';
const inventoryPath = '$dataDirectory/inventory.json';
const auditPath = '$dataDirectory/security-events.jsonl';


// PRESENTATION LAYER: ANSI escape codes style terminal text. They affect appearance, not inventory logic.
const String reset = '\x1B[0m';
const String bold = '\x1B[1m';
const String cyan = '\x1B[36m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String red = '\x1B[31m';
const String dim = '\x1B[2m';

// Prints a horizontal divider. The optional color parameter lets callers choose its color.
void printRule([String color = cyan]) {
  print('$color${'━' * 72}$reset');
}

// Gives each menu area a consistent heading and divider.
void printSection(String title) {
  print('\n$bold$cyan$title$reset');
  printRule();
}

// Draws the application's opening banner and identifies the project scenario.
void printDashboardHeader() {
  print('\x1B[2J\x1B[H'); // Clear screen where supported.
  printRule(green);
  print('$bold$green'
      '   ███████╗████████╗ ██████╗  ██████╗██╗  ██╗ ██████╗ █████╗ ██████╗ ███████╗\n'
      '   ██╔════╝╚══██╔══╝██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔══██╗██╔════╝\n'
      '   ███████╗   ██║   ██║   ██║██║     █████╔╝ ██║     ███████║██████╔╝█████╗  \n'
      '   ╚════██║   ██║   ██║   ██║██║     ██╔═██╗ ██║     ██╔══██║██╔══██╗██╔══╝  \n'
      '   ███████║   ██║   ╚██████╔╝╚██████╗██║  ██╗╚██████╗██║  ██║██║  ██║███████╗\n'
      '   ╚══════╝   ╚═╝    ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝'
      '$reset');
  printRule(green);
  print('$bold SIERRA TRADING COMPANY$reset');
  print('Food Batch & Expiry Monitoring | StockCare Inventory Console');
  print('$yellow DEMONSTRATION MODE$reset  ${dim}Not connected to a live company system.$reset');
  printRule();
}

// Converts a DateTime into the consistent YYYY-MM-DD format used in saved files and reports.
String dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

// AUDIT LOG: records important events so an operator can review successes and rejected actions.
// This log stores summaries rather than the raw suspicious text typed by a user.
class SecurityLog {
  // static means callers can write SecurityLog.record(...) without creating a SecurityLog object.
  // try/catch prevents a logging problem from crashing the whole application.
  static void record(String event, String field, String outcome, String details) {
    try {
      Directory(dataDirectory).createSync(recursive: true);
      final entry = <String, Object>{
        'timestamp': DateTime.now().toIso8601String(),
        'event': event,
        'field': field,
        'outcome': outcome,
        'details': details,
      };
      File(auditPath).writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append, flush: true);
    } catch (error) {
      stderr.writeln('WARNING: Security event could not be saved. Check disk access. ($error)');
    }
  }
}

// DATA MODEL: one StockBatch object represents one delivery/lot of a product.
// Two deliveries of the same product can be separate batches with different expiry dates.
class StockBatch {
  final String id;
  final String productName;
  final String unit;
  final DateTime receivedDate;
  final DateTime expiryDate;
  final int quantityReceived;
  final double unitCost;
  int quantityRemaining;
  bool archived;

  StockBatch({
    required this.id,
    required this.productName,
    required this.unit,
    required this.receivedDate,
    required this.expiryDate,
    required this.quantityReceived,
    required this.quantityRemaining,
    required this.unitCost,
    this.archived = false,
  });

  // Serialize a movement so it can be stored alongside inventory data.
  Map<String, Object> toJson() => {
    'id': id, 'productName': productName, 'unit': unit,
    'receivedDate': dateText(receivedDate), 'expiryDate': dateText(expiryDate),
    'quantityReceived': quantityReceived, 'quantityRemaining': quantityRemaining,
    'unitCost': unitCost, 'archived': archived,
  };

  // Rebuilds a StockBatch object from data read out of the JSON inventory file.
  factory StockBatch.fromJson(Map<String, dynamic> json) => StockBatch(
    id: json['id'] as String,
    productName: json['productName'] as String,
    unit: json['unit'] as String,
    receivedDate: DateTime.parse(json['receivedDate'] as String),
    expiryDate: DateTime.parse(json['expiryDate'] as String),
    quantityReceived: json['quantityReceived'] as int,
    quantityRemaining: json['quantityRemaining'] as int,
    unitCost: (json['unitCost'] as num).toDouble(),
    archived: json['archived'] as bool? ?? false,
  );
}

// A movement is a historical event, such as registering stock, selling it, or disposing of it.
// Keeping movements separately lets us show a batch's history after its quantity changes.
class StockMovement {
  final String batchId;
  final String type;
  final int quantity;
  final DateTime date;
  final String note;
  final double unitCostAtTime;

  StockMovement(this.batchId, this.type, this.quantity, this.date, this.note, this.unitCostAtTime);

  Map<String, Object> toJson() => {
    'batchId': batchId, 'type': type, 'quantity': quantity,
    'date': date.toIso8601String(), 'note': note, 'unitCostAtTime': unitCostAtTime,
  };

  // Deserialize one saved movement. The numeric conversion supports integer or decimal JSON costs.
  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    json['batchId'] as String, json['type'] as String, json['quantity'] as int,
    DateTime.parse(json['date'] as String), json['note'] as String,
    (json['unitCostAtTime'] as num?)?.toDouble() ?? 0,
  );
}

// CORE BUSINESS LOGIC: this class manages batches, movements, stock rules, and saving/loading.
class StockCare {
  final List<StockBatch> batches = [];
  final List<StockMovement> movements = [];

  // The constructor runs when StockCare() is created. It loads saved data if available.
  // Demo batches are created only when no inventory file exists yet.
  StockCare() {
    Directory(dataDirectory).createSync(recursive: true);
    final file = File(inventoryPath);
    // IMPORTANT: if saved data exists, prefer it over demo data so old records are preserved.
    if (file.existsSync()) {
      try {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        batches.addAll((data['batches'] as List<dynamic>).map(
          (item) => StockBatch.fromJson(Map<String, dynamic>.from(item as Map))));
        movements.addAll(((data['movements'] as List<dynamic>?) ?? []).map(
          (item) => StockMovement.fromJson(Map<String, dynamic>.from(item as Map))));
        SecurityLog.record('DATA_LOAD', 'inventory', 'SUCCESS', 'Saved inventory loaded.');
        return;
      } catch (error) {
        SecurityLog.record('DATA_LOAD', 'inventory', 'FAILURE', 'Saved data could not be read; no demo data was loaded automatically.');
        stderr.writeln('Saved inventory could not be read. Preserve $inventoryPath before attempting recovery.');
        rethrow;
      }
    }
    // First launch only: these are fictional examples for testing, not company records.
    final today = DateTime.now();
    batches.addAll([
      StockBatch(id: 'DEMO-M01', productName: 'Milk', unit: 'cartons',
        receivedDate: today.subtract(const Duration(days: 2)),
        expiryDate: today.add(const Duration(days: 4)), quantityReceived: 10,
        quantityRemaining: 10, unitCost: 20),
      StockBatch(id: 'DEMO-M02', productName: 'Milk', unit: 'cartons',
        receivedDate: today, expiryDate: today.add(const Duration(days: 15)),
        quantityReceived: 20, quantityRemaining: 20, unitCost: 20),
    ]);
    save();
    SecurityLog.record('INITIALIZE', 'inventory', 'SUCCESS', 'Fictional demo inventory initialized.');
  }

  // PERSISTENCE: write the current batches and movements to a temporary file, then rename it.
  // This reduces the risk of leaving a half-written inventory file if writing is interrupted.
  void save() {
    Directory(dataDirectory).createSync(recursive: true);
    final payload = {
      'schemaVersion': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'batches': batches.map((item) => item.toJson()).toList(),
      'movements': movements.map((item) => item.toJson()).toList(),
    };
    final temp = File('$inventoryPath.tmp');
    temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    temp.renameSync(inventoryPath);
  }

  // Removes the time-of-day portion so expiry comparisons are based on calendar days.
  static DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  // Patterns restrict IDs and product names to formats accepted by this prototype.
  // ^ and $ mean the whole value must match; {1,39} limits the number of characters.
  static final RegExp batchIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{1,39}$');
  static final RegExp productPattern = RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .,'()&/-]{0,79}$");

  // REGISTER: validate every important field before adding the batch to the live list.
  // A duplicate ID is rejected, but matching product names or dates can be legitimate.
  void addBatch(StockBatch batch) {
    if (findBatch(batch.id) != null) throw ArgumentError('Batch ID already exists.');
    if (!batchIdPattern.hasMatch(batch.id)) throw ArgumentError('Invalid batch ID format.');
    if (!productPattern.hasMatch(batch.productName) || !RegExp(r'[A-Za-z]').hasMatch(batch.productName)) {
      throw ArgumentError('Invalid product name.');
    }
    if (batch.quantityReceived <= 0 || batch.quantityRemaining <= 0 ||
        batch.quantityRemaining > batch.quantityReceived) throw ArgumentError('Enter a valid positive quantity.');
    if (!batch.unitCost.isFinite || batch.unitCost <= 0) throw ArgumentError('Unit cost must be a finite number greater than zero.');
    if (!RegExp(r'^[A-Za-z][A-Za-z ]{0,19}$').hasMatch(batch.unit)) throw ArgumentError('Invalid unit.');
    if (dayOnly(batch.expiryDate).isBefore(dayOnly(batch.receivedDate))) throw ArgumentError('Expiry date cannot be before the received date.');
    batches.add(batch);
    movements.add(StockMovement(batch.id, 'REGISTER', batch.quantityReceived, DateTime.now(), 'Batch registered', batch.unitCost));
    save();
    SecurityLog.record('BATCH_REGISTER', 'batchId', 'SUCCESS', 'A batch was registered.');
  }

  // The ? in StockBatch? means this function may return a batch or null if none matches.
  // IDs are compared case-insensitively, so 'milk-01' and 'MILK-01' count as the same ID.
  StockBatch? findBatch(String id) {
    for (final batch in batches) {
      if (batch.id.toLowerCase() == id.trim().toLowerCase()) return batch;
    }
    return null;
  }

  // Determines the status label shown in the inventory table.
  // Expired stock is labelled for removal; this does not physically remove its record.
  String statusOf(StockBatch batch, DateTime today, int alertDays) {
    if (batch.archived) return 'ARCHIVED';
    if (batch.quantityRemaining == 0) return 'DEPLETED';
    final days = dayOnly(batch.expiryDate).difference(dayOnly(today)).inDays;
    if (days < 0) return 'EXPIRED - REMOVE FROM SALE';
    if (days <= alertDays) return 'EXPIRING SOON ($days day(s))';
    return 'IN DATE';
  }

  // Returns active batches expiring today or within the chosen alert window, earliest first.
  List<StockBatch> approachingExpiry(DateTime today, int alertDays) => batches
    .where((b) => !b.archived && b.quantityRemaining > 0)
    .where((b) {
      final days = dayOnly(b.expiryDate).difference(dayOnly(today)).inDays;
      return days >= 0 && days <= alertDays;
    }).toList()..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  // FEFO means First Expired, First Out: sort eligible, non-expired stock by expiry date.
  List<StockBatch> fefoOrder(DateTime today) => batches
    .where((b) => !b.archived && b.quantityRemaining > 0)
    .where((b) => !dayOnly(b.expiryDate).isBefore(dayOnly(today)))
    .toList()..sort((a, b) {
      final cmp = a.expiryDate.compareTo(b.expiryDate);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });

  // SALE: check the batch, quantity, expiry, and available balance before changing stock.
  // The stock change and movement history are saved together after validation succeeds.
  void recordSale(String batchId, int quantity, DateTime today) {
    final batch = findBatch(batchId);
    if (batch == null || batch.archived) throw ArgumentError('Active batch not found.');
    if (quantity <= 0) throw ArgumentError('Quantity must be greater than zero.');
    if (dayOnly(batch.expiryDate).isBefore(dayOnly(today))) throw ArgumentError('Expired stock cannot be recorded as a sale.');
    if (quantity > batch.quantityRemaining) throw ArgumentError('Sale exceeds available quantity.');
    batch.quantityRemaining -= quantity;
    movements.add(StockMovement(batch.id, 'SALE', quantity, today, 'Recorded sale', batch.unitCost));
    save();
    SecurityLog.record('SALE', 'inventory', 'SUCCESS', 'Sale recorded for a known batch.');
  }

  // DISPOSAL: subtract discarded stock and return its purchase cost for the report.
  // Returning a double lets the menu display a currency amount with two decimal places.
  double recordDisposal(String batchId, int quantity, String reason, DateTime today) {
    final batch = findBatch(batchId);
    if (batch == null || batch.archived) throw ArgumentError('Active batch not found.');
    if (quantity <= 0) throw ArgumentError('Quantity must be greater than zero.');
    if (quantity > batch.quantityRemaining) throw ArgumentError('Disposal exceeds available quantity.');
    if (reason.trim().isEmpty || !RegExp(r'[A-Za-z]').hasMatch(reason)) throw ArgumentError('Disposal reason must include a text description.');
    batch.quantityRemaining -= quantity;
    movements.add(StockMovement(batch.id, 'DISPOSAL', quantity, today, reason.trim(), batch.unitCost));
    save();
    SecurityLog.record('DISPOSAL', 'inventory', 'SUCCESS', 'Disposal recorded.');
    return quantity * batch.unitCost;
  }

  // fold() adds the purchase cost of every disposal movement to produce one total.
  double totalDisposalCost() => movements
    .where((m) => m.type == 'DISPOSAL')
    .fold(0.0, (sum, m) => sum + m.quantity * m.unitCostAtTime);

  // Filters the full movement list to the chosen batch, then sorts events oldest to newest.
  List<StockMovement> historyFor(String id) =>
    movements.where((m) => m.batchId.toLowerCase() == id.toLowerCase()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

  // ARCHIVE instead of delete: only zero-stock batches can be archived, preserving history.
  void archiveBatch(StockBatch batch, String reason) {
    if (batch.archived) throw ArgumentError('Batch is already archived.');
    if (batch.quantityRemaining != 0) throw ArgumentError('Only depleted batches can be archived. Record a sale or disposal first.');
    if (reason.trim().length < 3 || !RegExp(r'[A-Za-z]').hasMatch(reason)) throw ArgumentError('Provide a meaningful archive reason.');
    batch.archived = true;
    movements.add(StockMovement(batch.id, 'ARCHIVE', 0, DateTime.now(), reason.trim(), batch.unitCost));
    save();
    SecurityLog.record('BATCH_ARCHIVE', 'batchId', 'SUCCESS', 'A depleted batch was archived with a reason.');
  }
}

// INPUT HELPERS: these functions collect text from the keyboard and apply basic checks.
// Named optional parameters (inside {}) let callers customize the field name and max length.
String readText(String prompt, {String field = 'input', int maxLength = 200}) {
  stdout.write(prompt);
  final value = stdin.readLineSync();
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.length > maxLength) {
    SecurityLog.record('INPUT_VALIDATION_FAILURE', field, 'REJECTED', 'Input exceeded the maximum permitted length (${trimmed.length} characters). Raw input was not saved.');
    print('Input too long. Maximum allowed length is $maxLength characters.');
    return '';
  }
  return trimmed;
}

// Keeps asking until the user enters an acceptable ID that is not already in the inventory.
String readBatchId(StockCare system) {
  while (true) {
    final value = readText('Batch ID: ', field: 'batchId', maxLength: 100);
    if (!StockCare.batchIdPattern.hasMatch(value)) {
      SecurityLog.record('INPUT_VALIDATION_FAILURE', 'batchId', 'REJECTED', 'Unsupported batch ID format; raw input not stored.');
      print('Invalid batch ID. Use 2-40 characters: letters, numbers, hyphens, or underscores.');
      continue;
    }
    if (system.findBatch(value) != null) {
      SecurityLog.record('DUPLICATE_BATCH_ATTEMPT', 'batchId', 'REJECTED', 'A duplicate batch ID was attempted; raw input not stored.');
      print('Batch ID already exists. Enter a unique ID.');
      continue;
    }
    return value;
  }
}

// Repeats the question when a product name is blank or contains unsupported characters.
String readProductName() {
  while (true) {
    final value = readText('Product name: ', field: 'productName', maxLength: 200);
    if (!StockCare.productPattern.hasMatch(value) || !RegExp(r'[A-Za-z]').hasMatch(value)) {
      SecurityLog.record('INPUT_VALIDATION_FAILURE', 'productName', 'REJECTED', 'Invalid product-name format; raw input not stored.');
      print('Invalid product name. Use letters/numbers and normal punctuation (max 80 characters).');
      continue;
    }
    return value;
  }
}

// Limits units to the approved list so inventory quantities remain understandable and consistent.
String readUnit() {
  const units = <String>[
    'carton', 'cartons', 'bag', 'bags', 'bottle', 'bottles', 'kg', 'g',
    'gram', 'grams', 'litre', 'litres', 'liter', 'liters', 'piece', 'pieces',
    'pack', 'packs', 'box', 'boxes', 'can', 'cans', 'crate', 'crates',
    'sack', 'sacks', 'dozen', 'unit', 'units',
  ];
  while (true) {
    final value = readText('Unit (cartons, bags, bottles, kg, g, etc.): ', field: 'unit', maxLength: 100).toLowerCase();
    if (units.contains(value)) return value;
    SecurityLog.record('INPUT_VALIDATION_FAILURE', 'unit', 'REJECTED', 'Unrecognized stock unit; raw input not stored.');
    print('Unrecognized unit. Choose an approved unit such as cartons, bags, bottles, kg, g, litres, or pieces.');
  }
}

// Repeats until the user supplies a real calendar date in YYYY-MM-DD format.
DateTime readValidDate(String prompt, {String field = 'date'}) {
  while (true) {
    final value = readText(prompt, field: field, maxLength: 40);
    final parsed = parseDate(value);
    if (parsed != null) return parsed;
    SecurityLog.record('INPUT_VALIDATION_FAILURE', field, 'REJECTED', 'Invalid date format or calendar date; raw input not stored.');
    print('Invalid date. Enter a real calendar date in YYYY-MM-DD format (example: ${dateText(DateTime.now())}).');
  }
}

// Parses dates safely. A nullable DateTime? result means invalid dates return null instead of crashing.
DateTime? parseDate(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
  ).firstMatch(value.trim());

  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  final parsed = DateTime(year, month, day);

  // DateTime normalizes out-of-range dates, so verify the original components.
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day) {
    return null;
  }

  return parsed;
}

// Reads a whole-number quantity and rejects zero, negative values, and non-numeric text.
int readPositiveInt(String prompt, {String field = 'quantity'}) {
  while (true) {
    final value = readText(prompt, field: field, maxLength: 40);
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
    SecurityLog.record('INPUT_VALIDATION_FAILURE', field, 'REJECTED', 'Expected a positive whole number; raw input not stored.');
    print('Invalid quantity. Enter a positive whole number, such as 1 or 25.');
  }
}

// Reads a positive purchase cost; a double supports values such as 12.50.
double readPositiveCost(String prompt) {
  while (true) {
    final value = readText('Unit purchase cost in NLe: ', field: 'unitCost', maxLength: 40);
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite && parsed > 0) return parsed;
    SecurityLog.record('INPUT_VALIDATION_FAILURE', 'unitCost', 'REJECTED', 'Expected a finite positive amount; raw input not stored.');
    print('Invalid purchase cost. Enter a positive amount, such as 400 or 25.50.');
  }
}

// Lets the operator choose how many days ahead expiry alerts should cover.
int readAlertDays() {
  while (true) {
    final value = readText('Expiry alert period in days (0-365, default 7): ', field: 'alertDays', maxLength: 20);
    if (value.isEmpty) return 7;
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0 && parsed <= 365) return parsed;
    SecurityLog.record('INPUT_VALIDATION_FAILURE', 'alertDays', 'REJECTED', 'Alert period must be a whole number from 0 to 365.');
    print('Enter a whole number from 0 to 365, or press Enter for 7.');
  }
}

// DISPLAY: prints inventory rows. Archived batches are hidden unless explicitly requested.
void printInventory(StockCare system, DateTime today, int alertDays, {bool includeArchived = false}) {
  final rows = system.batches.where((b) => includeArchived || !b.archived).toList();
  if (rows.isEmpty) {
    print('$yellow No matching stock batches recorded.$reset');
    return;
  }
  printSection('INVENTORY REGISTER');
  print('ID | Product | Remaining | Expiry | Status');
  for (final batch in rows) {
    print('${batch.id} | ${batch.productName} | ${batch.quantityRemaining} ${batch.unit} | ${dateText(batch.expiryDate)} | ${system.statusOf(batch, today, alertDays)}');
  }
}

// SEARCH: finds batch IDs or product names using a case-insensitive partial match.
void searchBatch(StockCare system, DateTime today, int alertDays) {
  final query = readText('Search by batch ID or product name: ', field: 'search', maxLength: 100).toLowerCase();
  if (query.isEmpty) {
    SecurityLog.record('INPUT_VALIDATION_FAILURE', 'search', 'REJECTED', 'Empty search query.');
    print('Enter a batch ID or product name to search.');
    return;
  }
  final results = system.batches.where((b) =>
    b.id.toLowerCase().contains(query) || b.productName.toLowerCase().contains(query)).toList();
  SecurityLog.record('BATCH_SEARCH', 'search', 'SUCCESS', 'Search completed; ${results.length} matching record(s). Query text not stored.');
  if (results.isEmpty) {
    print('No matching batches found.');
    return;
  }
  for (final b in results) {
    print('\n${b.id} | ${b.productName}${b.archived ? ' | ARCHIVED' : ''}');
    print('Unit: ${b.unit} | Received: ${dateText(b.receivedDate)} | Expiry: ${dateText(b.expiryDate)}');
    print('Received: ${b.quantityReceived} | Remaining: ${b.quantityRemaining} | Unit cost: NLe ${b.unitCost.toStringAsFixed(2)}');
    print('Status: ${system.statusOf(b, today, alertDays)}');
  }
}

// HISTORY: displays each recorded movement for one batch, in date order.
void viewHistory(StockCare system) {
  final id = readText('Batch ID for history: ', field: 'batchId', maxLength: 100);
  final batch = system.findBatch(id);
  if (batch == null) {
    SecurityLog.record('UNKNOWN_BATCH_LOOKUP', 'batchId', 'REJECTED', 'History requested for an unknown batch ID; value not stored.');
    print('Batch not found.');
    return;
  }
  final history = system.historyFor(batch.id);
  print('\nMovement history for ${batch.id} (${batch.productName})');
  if (history.isEmpty) {
    print('No movements recorded.');
    return;
  }
  for (final item in history) {
    print('${item.date.toIso8601String()} | ${item.type} | qty ${item.quantity} | ${item.note}');
  }
}

// MENU HANDLER: asks for a batch and reason, then calls the business-rule method to archive it.
void archiveBatch(StockCare system) {
  final id = readText('Batch ID to archive: ', field: 'batchId', maxLength: 100);
  final batch = system.findBatch(id);
  if (batch == null) {
    SecurityLog.record('UNKNOWN_BATCH_LOOKUP', 'batchId', 'REJECTED', 'Archive requested for an unknown batch ID; value not stored.');
    print('Batch not found.');
    return;
  }
  final reason = readText('Reason for archiving: ', field: 'archiveReason', maxLength: 200);
  try {
    system.archiveBatch(batch, reason);
    print('Batch archived. The record and movement history are retained.');
  } on ArgumentError catch (error) {
    SecurityLog.record('ARCHIVE_ATTEMPT', 'batchId', 'REJECTED', 'Archive rejected: ${error.message}');
    print('Archive not completed: ${error.message}');
  }
}

// Displays recent audit events so the operator can review validation failures and other actions.
void showSecurityLog() {
  final file = File(auditPath);
  if (!file.existsSync()) {
    print('No security events have been recorded.');
    return;
  }
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) {
    print('No security events have been recorded.');
    return;
  }
  print('\nRecent security events (newest last; raw input is not stored):');
  for (final line in lines.reversed.take(30).toList().reversed) {
    try {
      final item = jsonDecode(line) as Map<String, dynamic>;
      print('${item['timestamp']} | ${item['event']} | ${item['field']} | ${item['outcome']} | ${item['details']}');
    } catch (_) {
      print('[Unreadable log entry omitted]');
    }
  }
  print('Showing up to 30 recent events. Log file: $auditPath');
}

// PROGRAM ENTRY POINT: Dart starts here when you run `dart run stockcare.dart`.
// main() creates the system, shows the dashboard, then loops until the user chooses Exit.
void main() {
  late final StockCare system;
  try {
    system = StockCare();
  } catch (error) {
    stderr.writeln('StockCare could not safely load saved data: $error');
    exitCode = 1;
    return;
  }

  printDashboardHeader();
  print('Data file: $dim$inventoryPath$reset');
  print('Audit log: $dim$auditPath$reset');
  print('Tip: choose an option below; your inventory is saved locally.');
  final alertDays = readAlertDays();

  // A loop keeps the menu open after each action. The date is refreshed each time around.
  while (true) {
    final today = DateTime.now();
    printSection('MAIN MENU');
    print('  ${green}1$reset  View inventory                 ${green}7$reset  Register a batch');
    print('  ${green}2$reset  Expiry alerts                  ${green}8$reset  Search batch/product');
    print('  ${green}3$reset  FEFO recommendation            ${green}9$reset  Batch details/history');
    print('  ${green}4$reset  Record sale                    ${green}10$reset Archive depleted batch');
    print('  ${green}5$reset  Record disposal                ${green}11$reset Security event log');
    print('  ${green}6$reset  Waste-cost summary             ${red}0$reset  Exit');
    printRule();
    final choice = readText('Choose an option: ', field: 'menuChoice', maxLength: 20);
    if (choice == '0') {
      SecurityLog.record('SESSION_END', 'application', 'SUCCESS', 'StockCare closed normally.');
      print('StockCare closed. Saved data remains in $dataDirectory.');
      break;
    }

    // switch routes the selected menu number to the matching feature.
    // try/catch turns expected business-rule errors into readable messages rather than a crash.
    try {
      switch (choice) {
        case '1':
          printInventory(system, today, alertDays);
          break;
        case '2':
          final rows = system.approachingExpiry(today, alertDays);
          print(rows.isEmpty ? 'No batches are within the $alertDays-day alert period.'
            : 'Approaching expiry: ${rows.map((b) => '${b.id} (${dateText(b.expiryDate)})').join(', ')}');
          break;
        case '3':
          final rows = system.fefoOrder(today);
          print(rows.isEmpty ? 'No eligible stock is available.'
            : 'Sell first: ${rows.first.id} - ${rows.first.productName} (expires ${dateText(rows.first.expiryDate)}).');
          break;
        case '4':
          final id = readText('Batch ID: ', field: 'batchId', maxLength: 100);
          final quantity = readPositiveInt('Quantity sold: ', field: 'saleQuantity');
          system.recordSale(id, quantity, today);
          print('Sale recorded.');
          break;
        case '5':
          final id = readText('Batch ID: ', field: 'batchId', maxLength: 100);
          final quantity = readPositiveInt('Quantity discarded: ', field: 'disposalQuantity');
          final reason = readText('Reason: ', field: 'disposalReason', maxLength: 200);
          final cost = system.recordDisposal(id, quantity, reason, today);
          print('Disposal recorded. Purchase cost of discarded stock: NLe ${cost.toStringAsFixed(2)}');
          break;
        case '6':
          print('Recorded disposal purchase cost: NLe ${system.totalDisposalCost().toStringAsFixed(2)}');
          break;
        case '7':
          final id = readBatchId(system);
          final name = readProductName();
          final unit = readUnit();
          final received = readValidDate('Received date (YYYY-MM-DD): ', field: 'receivedDate');
          late DateTime expiry;
          while (true) {
            expiry = readValidDate('Expiry date (YYYY-MM-DD): ', field: 'expiryDate');
            if (!StockCare.dayOnly(expiry).isBefore(StockCare.dayOnly(received))) break;
            SecurityLog.record('INPUT_VALIDATION_FAILURE', 'expiryDate', 'REJECTED', 'Expiry date precedes received date.');
            print('Expiry date cannot be before the received date. Enter the expiry date again.');
          }
          final quantity = readPositiveInt('Quantity received: ', field: 'receivedQuantity');
          final cost = readPositiveCost('Unit purchase cost in NLe: ');
          system.addBatch(StockBatch(id: id, productName: name, unit: unit,
            receivedDate: received, expiryDate: expiry, quantityReceived: quantity,
            quantityRemaining: quantity, unitCost: cost));
          print('Batch registered successfully and saved.');
          break;
        case '8':
          searchBatch(system, today, alertDays);
          break;
        case '9':
          viewHistory(system);
          break;
        case '10':
          archiveBatch(system);
          break;
        case '11':
          showSecurityLog();
          break;
        default:
          SecurityLog.record('INVALID_MENU_CHOICE', 'menuChoice', 'REJECTED', 'Unsupported menu option; raw input not stored.');
          print('Invalid option. Choose a listed number.');
      }
    } on ArgumentError catch (error) {
      SecurityLog.record('OPERATION_REJECTED', 'operation', 'REJECTED', 'Operation rejected: ${error.message}');
      print('Operation not completed: ${error.message}');
    } on FileSystemException catch (error) {
      SecurityLog.record('PERSISTENCE_FAILURE', 'storage', 'FAILURE', 'A file operation failed. Review local file permissions.');
      print('Storage error: changes may not have been saved. Check disk space and folder permissions. $error');
    }
  }
}