import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================

class Trip {
  String id;
  String title;
  DateTime date;
  String ownerId;
  List<Person> people;
  List<Expense> expenses;

  Trip({required this.id, required this.title, required this.date, required this.ownerId, required this.people, required this.expenses});

  factory Trip.fromMap(String documentId, Map<String, dynamic> map) {
    return Trip(
      id: documentId,
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      ownerId: map['ownerId'] ?? '',
      people: (map['people'] as List<dynamic>? ?? []).map((p) => Person.fromMap(p)).toList(),
      expenses: (map['expenses'] as List<dynamic>? ?? []).map((e) => Expense.fromMap(e)).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'ownerId': ownerId,
        'people': people.map((p) => p.toMap()).toList(),
        'expenses': expenses.map((e) => e.toMap()).toList(),
      };
}

class Person {
  String id;
  String name;
  String email; // NEW: Added Email for real user tracking

  Person({required this.id, required this.name, required this.email});

  factory Person.fromMap(Map<String, dynamic> map) => Person(id: map['id'], name: map['name'], email: map['email'] ?? '');
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'email': email};
}

class Expense {
  String id;
  String description;
  double amount;
  String payerId;
  List<String> involvedIds;

  Expense({required this.id, required this.description, required this.amount, required this.payerId, required this.involvedIds});

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'],
        description: map['description'],
        amount: (map['amount'] as num).toDouble(),
        payerId: map['payerId'],
        involvedIds: List<String>.from(map['involvedIds']),
      );

  Map<String, dynamic> toMap() => {'id': id, 'description': description, 'amount': amount, 'payerId': payerId, 'involvedIds': involvedIds};
}

// ==========================================
// 2. MAIN APP & THEME
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Split',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), primary: const Color(0xFF4F46E5), secondary: const Color(0xFF10B981)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF4F46E5), foregroundColor: Colors.white, centerTitle: true, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const TripListScreen();
        return const LoginScreen();
      },
    );
  }
}

// ==========================================
// 3. LOGIN & REGISTER (With beautiful UI)
// ==========================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // NEW: For registration
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      } else {
        if (_nameController.text.trim().isEmpty) throw Exception("Please enter your name");
        
        // Register User
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Save to Firestore 'users' collection for searching later
        // Save to Firestore 'users' collection for searching later
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'email': cred.user!.email!.toLowerCase(), // FORCE LOWERCASE HERE
          'name': _nameController.text.trim(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flight_takeoff, size: 64, color: Color(0xFF4F46E5)),
                  const SizedBox(height: 16),
                  Text(_isLogin ? "Welcome Back" : "Create Account", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 32),
                  if (!_isLogin) ...[
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 16),
                  ],
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)), obscureText: true),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: Text(_isLogin ? "LOGIN" : "REGISTER", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? "Don't have an account? Sign up" : "Already have an account? Log in", style: const TextStyle(color: Color(0xFF4F46E5))),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. CLOUD TRIP LIST SCREEN (LIVE SYNC)
// ==========================================

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  void _showAddTripDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Where to next?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1F2937))),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: "e.g. Goa Vacation",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 24, bottom: 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser!;
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                final userName = userDoc.data()?['name'] ?? 'Me';

                await FirebaseFirestore.instance.collection('trips').add({
                  'title': controller.text.trim(),
                  'date': Timestamp.now(),
                  'ownerId': user.uid,
                  'people': [{'id': user.uid, 'name': userName, 'email': user.email}], 
                  'expenses': [],
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text("Create Trip", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTripDialog(BuildContext context, Trip trip) {
    TextEditingController controller = TextEditingController(text: trip.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Edit Trip Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1F2937))),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 24, bottom: 24),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('trips').doc(trip.id).update({
                  'title': controller.text.trim()
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Trips", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      // This StreamBuilder ensures the list updates instantly when data changes in the cloud
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('trips').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final tripsData = snapshot.data?.docs.where((doc) {
            final tripData = doc.data() as Map<String, dynamic>;
            final peopleList = tripData['people'] as List<dynamic>? ?? [];
            return peopleList.any((p) => p['id'] == user.uid);
          }).toList() ?? [];

          if (tripsData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_outlined, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No trips yet.", style: TextStyle(fontSize: 20, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: tripsData.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final trip = Trip.fromMap(tripsData[index].id, tripsData[index].data() as Map<String, dynamic>);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip))),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            height: 60, width: 60,
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.landscape, color: Color(0xFF4F46E5), size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                const SizedBox(height: 4),
                                Text(DateFormat.yMMMd().format(trip.date), style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                              ],
                            ),
                          ),
                          if (trip.ownerId == user.uid)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showEditTripDialog(context, trip);
                                } else if (value == 'delete') {
                                  await FirebaseFirestore.instance.collection('trips').doc(trip.id).delete();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text("Edit Name")])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete Trip")])),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTripDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("New Trip", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ==========================================
// 5. CLOUD TRIP DETAILS SCREEN (LIVE SYNC)
// ==========================================

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _selectedIndex = 0;
  String _sortOption = 'newest';
  String _filterPayerId = 'all';

  // We now pass the live trip into this function so it uploads the newest version
  Future<void> _updateCloudTrip(Trip liveTrip) async {
    await FirebaseFirestore.instance.collection('trips').doc(liveTrip.id).update(liveTrip.toMap());
    // Notice we removed setState({}) here! 
    // The StreamBuilder will automatically detect the cloud change and refresh the UI.
  }

  void _showSearchPersonDialog(Trip liveTrip) {
    TextEditingController emailController = TextEditingController();
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("Add Friend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1F2937))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Enter their registered app email.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "friend@email.com",
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (isSearching) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
              ],
            ),
            actionsPadding: const EdgeInsets.only(right: 24, bottom: 24),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))),
              ElevatedButton(
                onPressed: () async {
                  if (emailController.text.trim().isEmpty) return;
                  setDialogState(() => isSearching = true);
                  
                  final searchQuery = emailController.text.trim().toLowerCase();
                  final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: searchQuery).get();
                  
                  if (query.docs.isEmpty) {
                    setDialogState(() => isSearching = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found! They must register in the app first.")));
                    return;
                  }

                  final userData = query.docs.first.data();
                  
                  if (liveTrip.people.any((p) => p.id == userData['uid'])) {
                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User is already in this trip!")));
                  } else {
                     liveTrip.people.add(Person(id: userData['uid'], name: userData['name'], email: userData['email']));
                     await _updateCloudTrip(liveTrip);
                     if (mounted) Navigator.pop(dialogContext);
                  }
                  setDialogState(() => isSearching = false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: const Text("Find & Add", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  void _removePerson(Person person, Trip liveTrip) {
    if (person.id == liveTrip.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot remove the Trip Creator!")));
      return;
    }

    bool isInvolved = liveTrip.expenses.any((e) => e.payerId == person.id || e.involvedIds.contains(person.id));

    if (isInvolved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot remove ${person.name}. They are involved in expenses! Delete those expenses first."), backgroundColor: Colors.redAccent));
    } else {
      liveTrip.people.removeWhere((p) => p.id == person.id);
      _updateCloudTrip(liveTrip); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${person.name} removed."), backgroundColor: const Color(0xFF10B981)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // NEW: StreamBuilder listens to this specific trip LIVE
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('trips').doc(widget.trip.id).snapshots(),
      builder: (context, snapshot) {
        
        // Use the initial trip data until the live data loads
        Trip liveTrip = widget.trip; 
        
        // If live data comes in, use it instead!
        if (snapshot.hasData && snapshot.data != null) {
          if (!snapshot.data!.exists) {
            // Safety check: In case a friend deletes the trip while you are looking at it
            return Scaffold(appBar: AppBar(title: const Text("Trip no longer exists")));
          }
          liveTrip = Trip.fromMap(snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);
        }

        final isCreator = liveTrip.ownerId == currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: Text(liveTrip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (_selectedIndex == 0 && isCreator) 
                IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: () => _showSearchPersonDialog(liveTrip))
            ],
          ),
          body: _buildBody(isCreator, liveTrip),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFEEF2FF),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF4F46E5)), label: 'Overview'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF4F46E5)), label: 'Expenses'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF4F46E5)), label: 'Balances'),
            ],
          ),
          floatingActionButton: _selectedIndex == 1 
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    if (liveTrip.people.isEmpty) return;
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(trip: liveTrip)));
                    _updateCloudTrip(liveTrip); 
                  },
                  icon: const Icon(Icons.add), label: const Text("Expense", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white,
                )
              : null,
        );
      }
    );
  }

  Widget _buildBody(bool isCreator, Trip liveTrip) {
    if (_selectedIndex == 0) return _buildOverview(isCreator, liveTrip);
    if (_selectedIndex == 1) return _buildExpenseList(liveTrip);
    return _buildBalances(liveTrip);
  }

  Widget _buildOverview(bool isCreator, Trip liveTrip) {
    double totalCost = 0;
    for (var e in liveTrip.expenses) { totalCost += e.amount; }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              const Text("Total Trip Expenses", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text("₹${totalCost.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text("Trip Members", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 16),
        ...liveTrip.people.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFEEF2FF), child: Text(p.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold))),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            trailing: p.id == liveTrip.ownerId
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: const Text("Creator", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)))
                : (isCreator ? IconButton(icon: const Icon(Icons.person_remove, color: Colors.redAccent), onPressed: () => _removePerson(p, liveTrip)) : null),
          ),
        ))
      ],
    );
  }

  // ==========================================
  // EXPENSE LIST WITH DYNAMIC SORTING
  // ==========================================
  // ==========================================
  // EXPENSE LIST WITH PAYER FILTER & SORTING
  // ==========================================
  Widget _buildExpenseList(Trip liveTrip) {
    if (liveTrip.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No expenses yet.", style: TextStyle(fontSize: 20, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // 1. Filter expenses based on selected payer
    List<Expense> filteredExpenses = liveTrip.expenses.where((e) {
      if (_filterPayerId == 'all') return true;
      return e.payerId == _filterPayerId;
    }).toList();

    // 2. Sort the filtered list
    if (_sortOption == 'newest') {
      filteredExpenses = filteredExpenses.reversed.toList();
    } else if (_sortOption == 'oldest') {
      // Retains default insertion order
    } else if (_sortOption == 'highest') {
      filteredExpenses.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortOption == 'lowest') {
      filteredExpenses.sort((a, b) => a.amount.compareTo(b.amount));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 3. Horizontal Payer Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text("All Payers"),
                selected: _filterPayerId == 'all',
                selectedColor: const Color(0xFF4F46E5),
                labelStyle: TextStyle(
                  color: _filterPayerId == 'all' ? Colors.white : const Color(0xFF1F2937),
                  fontWeight: FontWeight.bold,
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) setState(() => _filterPayerId = 'all');
                },
              ),
              const SizedBox(width: 8),
              ...liveTrip.people.map((p) {
                final isSelected = _filterPayerId == p.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text("Paid by ${p.name}"),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
                      fontWeight: FontWeight.bold,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        _filterPayerId = selected ? p.id : 'all';
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. Header with Count & Sort Control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${filteredExpenses.length} ${filteredExpenses.length == 1 ? 'Expense' : 'Expenses'}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 16),
              ),
              PopupMenuButton<String>(
                initialValue: _sortOption,
                onSelected: (value) => setState(() => _sortOption = value),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 18, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Text(
                        _getSortLabel(_sortOption),
                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'newest', child: Text("Newest First")),
                  const PopupMenuItem(value: 'oldest', child: Text("Oldest First")),
                  const PopupMenuItem(value: 'highest', child: Text("Highest Amount (₹↓)")),
                  const PopupMenuItem(value: 'lowest', child: Text("Lowest Amount (₹↑)")),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 5. Empty State for Filter
        if (filteredExpenses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.filter_alt_off_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    "No expenses paid by this person",
                    style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          )
        else
          // 6. Render Filtered & Sorted Expense Cards
          ...filteredExpenses.map((e) {
            final payerName = liveTrip.people.firstWhere(
              (p) => p.id == e.payerId,
              orElse: () => Person(id: '0', name: 'Unknown', email: ''),
            ).name;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt, color: Color(0xFF10B981)),
                ),
                title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("$payerName paid • ${e.involvedIds.length} split", style: TextStyle(color: Colors.grey[500])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "₹${e.amount.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AddExpenseScreen(trip: liveTrip, expenseToEdit: e)),
                          );
                          _updateCloudTrip(liveTrip);
                        } else if (value == 'delete') {
                          liveTrip.expenses.removeWhere((exp) => exp.id == e.id);
                          _updateCloudTrip(liveTrip);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense deleted")));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text("Edit")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete")])),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

  // Helper to get user-friendly label for current sort
  String _getSortLabel(String option) {
    switch (option) {
      case 'oldest':
        return 'Oldest';
      case 'highest':
        return 'Amount: High to Low';
      case 'lowest':
        return 'Amount: Low to High';
      case 'newest':
      default:
        return 'Newest';
    }
  }

  // ==========================================
  // SPLITWISE-STYLE DEBT SIMPLIFICATION & SETTLEMENTS
  // ==========================================
  Widget _buildBalances(Trip liveTrip) {
    // 1. Calculate net balances for each person
    Map<String, double> balances = { for (var p in liveTrip.people) p.id: 0.0 };
    for (var e in liveTrip.expenses) {
      if (e.involvedIds.isEmpty) continue;
      balances[e.payerId] = (balances[e.payerId] ?? 0) + e.amount;
      double split = e.amount / e.involvedIds.length;
      for (var id in e.involvedIds) {
        balances[id] = (balances[id] ?? 0) - split;
      }
    }

    // 2. Separate into Debtors (owes money) and Creditors (receives money)
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((id, amount) {
      double rounded = (amount * 100).roundToDouble() / 100;
      if (rounded < -0.01) {
        debtors.add(MapEntry(id, -rounded)); // Store as positive debt value
      } else if (rounded > 0.01) {
        creditors.add(MapEntry(id, rounded));
      }
    });

    // 3. Match debtors and creditors (Splitwise Greedy Settlement)
    List<Map<String, dynamic>> settlements = [];
    int d = 0;
    int c = 0;

    List<double> debtorAmounts = debtors.map((e) => e.value).toList();
    List<double> creditorAmounts = creditors.map((e) => e.value).toList();

    while (d < debtors.length && c < creditors.length) {
      double debtorOwes = debtorAmounts[d];
      double creditorGets = creditorAmounts[c];
      double settledAmount = debtorOwes < creditorGets ? debtorOwes : creditorGets;

      String fromName = liveTrip.people.firstWhere(
        (p) => p.id == debtors[d].key,
        orElse: () => Person(id: '', name: 'Unknown', email: ''),
      ).name;

      String toName = liveTrip.people.firstWhere(
        (p) => p.id == creditors[c].key,
        orElse: () => Person(id: '', name: 'Unknown', email: ''),
      ).name;

      settlements.add({
        'from': fromName,
        'to': toName,
        'amount': settledAmount,
      });

      debtorAmounts[d] -= settledAmount;
      creditorAmounts[c] -= settledAmount;

      if (debtorAmounts[d] < 0.01) d++;
      if (creditorAmounts[c] < 0.01) c++;
    }

    // 4. If all balances are settled
    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            const Text(
              "All settled up!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 4),
            Text(
              "No outstanding payments needed.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 5. Render Settlement Cards
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Suggested Settlements",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
        ),
        ...settlements.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Payer Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['from'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                    ),
                    const Text("pays", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              // Arrow Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward, color: Color(0xFF4F46E5), size: 18),
              ),
              // Receiver Name
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['to'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                      ),
                      const Text("receives", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              // Amount Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "₹${(s['amount'] as double).toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }



// ==========================================
// 6. ADD / EDIT EXPENSE SCREEN
// ==========================================

class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final Expense? expenseToEdit; // NEW: If this is provided, we are in "Edit Mode"
  
  const AddExpenseScreen({super.key, required this.trip, this.expenseToEdit});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedPayerId;
  Set<String> _selectedInvolvedIds = {};

  @override
  void initState() {
    super.initState();
    
    // Check if we are editing an existing expense
    if (widget.expenseToEdit != null) {
      _descController.text = widget.expenseToEdit!.description;
      _amountController.text = widget.expenseToEdit!.amount.toString();
      _selectedPayerId = widget.expenseToEdit!.payerId;
      _selectedInvolvedIds = widget.expenseToEdit!.involvedIds.toSet();
    } else {
      // Default for a new expense
      if (widget.trip.people.isNotEmpty) {
        _selectedPayerId = widget.trip.people.first.id;
        _selectedInvolvedIds = widget.trip.people.map((p) => p.id).toSet();
      }
    }
  }

  void _save() {
    final desc = _descController.text;
    final amount = double.tryParse(_amountController.text);
    if (desc.isEmpty || amount == null || _selectedPayerId == null || _selectedInvolvedIds.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields correctly.")));
       return;
    }

    if (widget.expenseToEdit != null) {
      // EDIT MODE: Update the existing expense
      widget.expenseToEdit!.description = desc;
      widget.expenseToEdit!.amount = amount;
      widget.expenseToEdit!.payerId = _selectedPayerId!;
      widget.expenseToEdit!.involvedIds = _selectedInvolvedIds.toList();
    } else {
      // ADD MODE: Create a brand new expense
      widget.trip.expenses.add(Expense(
        id: const Uuid().v4(), 
        description: desc, 
        amount: amount, 
        payerId: _selectedPayerId!, 
        involvedIds: _selectedInvolvedIds.toList()
      ));
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.expenseToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Expense" : "New Expense", style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                children: [
                  TextField(controller: _descController, decoration: const InputDecoration(labelText: "What was this for?", prefixIcon: Icon(Icons.fastfood_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixIcon: Icon(Icons.currency_rupee))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            const Text("Who paid?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: widget.trip.people.map((p) => ChoiceChip(
              label: Text(p.name, style: TextStyle(color: _selectedPayerId == p.id ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), 
              selected: _selectedPayerId == p.id, 
              selectedColor: const Color(0xFF4F46E5),
              showCheckmark: false,
              onSelected: (s) { if(s) setState(() => _selectedPayerId = p.id); }
            )).toList()),
            
            const SizedBox(height: 32),
            const Text("Who is splitting it?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: widget.trip.people.map((p) => FilterChip(
              label: Text(p.name, style: TextStyle(color: _selectedInvolvedIds.contains(p.id) ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), 
              selected: _selectedInvolvedIds.contains(p.id), 
              selectedColor: const Color(0xFF10B981),
              showCheckmark: false,
              onSelected: (s) { setState(() { s ? _selectedInvolvedIds.add(p.id) : _selectedInvolvedIds.remove(p.id); }); }
            )).toList()),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, 
              child: ElevatedButton(
                onPressed: _save, 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), 
                child: Text(isEditing ? "Update Expense" : "Save Expense", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              )
            )
          ],
        ),
      ),
    );
  }
}