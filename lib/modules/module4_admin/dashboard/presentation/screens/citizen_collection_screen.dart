import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/data/models/customer_profile.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/citizen_collection_repository.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/assignment_history_screen.dart';

class CitizenCollectionScreen extends StatefulWidget {
  const CitizenCollectionScreen({super.key});

  @override
  State<CitizenCollectionScreen> createState() =>
      _CitizenCollectionScreenState();
}

class _CitizenCollectionScreenState extends State<CitizenCollectionScreen> {
  final _repository = const CitizenCollectionRepository();
  final _searchController = TextEditingController();

  List<CustomerProfile> _customers = [];
  List<CustomerProfile> _filteredCustomers = [];
  List<String> _wardOptions = [];

  CustomerProfile? _selectedCustomer;
  List<EnhancedAssignmentModel> _selectedAssignments = [];

  bool _loadingCustomers = true;
  bool _loadingAssignments = false;
  String? _selectedWard;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loadingCustomers = true);
    final customers = await _repository.fetchCustomers();
    customers.sort((a, b) => a.name.compareTo(b.name));

    final wards = customers
        .map((customer) => customer.wardName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _wardOptions = wards;
      _loadingCustomers = false;
    });

    _applyFilters();

    if (_filteredCustomers.isNotEmpty && _selectedCustomer == null) {
      _selectCustomer(_filteredCustomers.first, autoNavigate: false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final wardFilter = _selectedWard;

    setState(() {
      _filteredCustomers = _customers.where((customer) {
        final matchesWard = wardFilter == null ||
            wardFilter.isEmpty ||
            customer.wardName == wardFilter;
        final matchesQuery = query.isEmpty ||
            customer.name.toLowerCase().contains(query) ||
            customer.contactNo.toLowerCase().contains(query) ||
            customer.wardName.toLowerCase().contains(query);
        return matchesWard && matchesQuery;
      }).toList();
    });

    if (_selectedCustomer != null &&
        !_filteredCustomers.contains(_selectedCustomer)) {
      setState(() {
        _selectedCustomer = _filteredCustomers.isNotEmpty
            ? _filteredCustomers.first
            : null;
      });
      if (_selectedCustomer != null) {
        _loadAssignmentsForCustomer(_selectedCustomer!);
      }
    }
  }

  Future<void> _loadAssignmentsForCustomer(CustomerProfile customer) async {
    setState(() {
      _loadingAssignments = true;
      _selectedAssignments = [];
    });

    final assignments = await _repository.fetchAssignments(
      customerId: customer.uniqueId,
    );

    if (!mounted) return;
    setState(() {
      _selectedAssignments = assignments;
      _loadingAssignments = false;
    });
  }

  void _selectCustomer(CustomerProfile customer, {required bool autoNavigate}) {
    setState(() {
      _selectedCustomer = customer;
    });
    _loadAssignmentsForCustomer(customer);

    if (autoNavigate) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CitizenDetailScreen(
            customer: customer,
            assignmentsLoader: () async {
              final assignments = await _repository.fetchAssignments(
                customerId: customer.uniqueId,
              );
              return assignments;
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('Citizen Collections'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingCustomers
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final listPane = _CitizenListPane(
                  searchController: _searchController,
                  wardOptions: _wardOptions,
                  selectedWard: _selectedWard,
                  customers: _filteredCustomers,
                  selectedCustomer: _selectedCustomer,
                  onWardChanged: (value) {
                    setState(() => _selectedWard = value);
                    _applyFilters();
                  },
                  onSearchChanged: (_) => _applyFilters(),
                  onCustomerSelected: (customer) {
                    if (isWide) {
                      _selectCustomer(customer, autoNavigate: false);
                    } else {
                      _selectCustomer(customer, autoNavigate: true);
                    }
                  },
                );

                if (!isWide) {
                  return listPane;
                }

                return Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: listPane,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _CitizenDetailPane(
                        customer: _selectedCustomer,
                        assignments: _selectedAssignments,
                        loadingAssignments: _loadingAssignments,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CitizenListPane extends StatelessWidget {
  const _CitizenListPane({
    required this.searchController,
    required this.wardOptions,
    required this.selectedWard,
    required this.customers,
    required this.selectedCustomer,
    required this.onWardChanged,
    required this.onSearchChanged,
    required this.onCustomerSelected,
  });

  final TextEditingController searchController;
  final List<String> wardOptions;
  final String? selectedWard;
  final List<CustomerProfile> customers;
  final CustomerProfile? selectedCustomer;
  final ValueChanged<String?> onWardChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CustomerProfile> onCustomerSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by name, phone, ward',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: selectedWard,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All wards'),
                  ),
                  ...wardOptions.map(
                    (ward) => DropdownMenuItem<String?>(
                      value: ward,
                      child: Text(ward),
                    ),
                  ),
                ],
                onChanged: onWardChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No citizens found'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final isSelected = selectedCustomer?.uniqueId ==
                        customer.uniqueId;
                    return _CitizenCard(
                      customer: customer,
                      selected: isSelected,
                      onTap: () => onCustomerSelected(customer),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CitizenCard extends StatelessWidget {
  const _CitizenCard({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final CustomerProfile customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2E7D32),
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.wardName,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  if (customer.contactNo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.contactNo,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CitizenDetailPane extends StatelessWidget {
  const _CitizenDetailPane({
    required this.customer,
    required this.assignments,
    required this.loadingAssignments,
  });

  final CustomerProfile? customer;
  final List<EnhancedAssignmentModel> assignments;
  final bool loadingAssignments;

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Select a citizen to view details'),
          ],
        ),
      );
    }

    if (loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }

    return _CitizenDetailView(
      customer: customer!,
      assignments: assignments,
    );
  }
}

class _CitizenDetailScreen extends StatelessWidget {
  const _CitizenDetailScreen({
    required this.customer,
    required this.assignmentsLoader,
  });

  final CustomerProfile customer;
  final Future<List<EnhancedAssignmentModel>> Function() assignmentsLoader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<EnhancedAssignmentModel>>(
        future: assignmentsLoader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = snapshot.data ?? [];
          return _CitizenDetailView(
            customer: customer,
            assignments: assignments,
          );
        },
      ),
    );
  }
}

class _CitizenDetailView extends StatelessWidget {
  const _CitizenDetailView({
    required this.customer,
    required this.assignments,
  });

  final CustomerProfile customer;
  final List<EnhancedAssignmentModel> assignments;

  @override
  Widget build(BuildContext context) {
    final stats = _CitizenStats.fromAssignments(assignments);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                customer.wardName,
                style: const TextStyle(color: Colors.white70),
              ),
              if (customer.address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  customer.address,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (customer.contactNo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Phone: ${customer.contactNo}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CitizenStatsRow(stats: stats),
        const SizedBox(height: 16),
        Text(
          'Recent collections',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No collection records yet.'),
          )
        else
          ...assignments.take(8).map(
                (assignment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AssignmentTile(assignment: assignment),
                ),
              ),
      ],
    );
  }
}

class _CitizenStatsRow extends StatelessWidget {
  const _CitizenStatsRow({required this.stats});

  final _CitizenStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Trips',
            value: '${stats.total}',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Completed',
            value: '${stats.completed}',
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Skipped',
            value: '${stats.skipped}',
            color: const Color(0xFFF57C00),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});

  final EnhancedAssignmentModel assignment;

  @override
  Widget build(BuildContext context) {
    final status = assignment.currentStatus;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailedAssignmentHistoryScreen(
              assignment: assignment,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: status.color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 14, color: status.color),
                      const SizedBox(width: 4),
                      Text(
                        status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(assignment.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              assignment.ward,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignment.driver,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.directions_car,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignment.operatorName,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CitizenStats {
  final int total;
  final int completed;
  final int skipped;
  final int pending;
  final int inProgress;
  final int cancelled;

  const _CitizenStats({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.pending,
    required this.inProgress,
    required this.cancelled,
  });

  factory _CitizenStats.fromAssignments(
      List<EnhancedAssignmentModel> assignments) {
    int completed = 0;
    int skipped = 0;
    int pending = 0;
    int inProgress = 0;
    int cancelled = 0;

    for (final assignment in assignments) {
      switch (assignment.currentStatus) {
        case AssignmentStatus.completed:
          completed++;
          break;
        case AssignmentStatus.skipped:
          skipped++;
          break;
        case AssignmentStatus.inProgress:
          inProgress++;
          break;
        case AssignmentStatus.cancelled:
          cancelled++;
          break;
        case AssignmentStatus.pending:
          pending++;
          break;
      }
    }

    return _CitizenStats(
      total: assignments.length,
      completed: completed,
      skipped: skipped,
      pending: pending,
      inProgress: inProgress,
      cancelled: cancelled,
    );
  }
}
