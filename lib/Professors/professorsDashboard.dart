import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  String _searchQuery = '';
  String _selectedActivity = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fetching data from attendance_logs and joining with profiles
  Future<void> _fetchData() async {
    try {
      final data = await supabase
          .from('attendance_logs')
          .select('*, profiles(display_name, college_code)')
          .order('check_in_time', ascending: false);

      setState(() {
        _allLogs = List<Map<String, dynamic>>.from(data);
        _filteredLogs = _allLogs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _runFilter() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final studentName = log['profiles']['display_name']
            .toString()
            .toLowerCase();
        final matchesSearch = studentName.contains(_searchQuery.toLowerCase());
        final matchesActivity =
            _selectedActivity == 'All' ||
            log['activity_type'] == _selectedActivity;
        return matchesSearch && matchesActivity;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Professor Admin Dashboard"),
      //   backgroundColor: Colors.indigo,
      //   foregroundColor: Colors.white,
      //   actions: [
      //     IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh)),
      //   ],
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- SEARCH & GROUP BY BAR ---
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search student name...",
                                prefixIcon: Icon(Icons.search),
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                _searchQuery = value;
                                _runFilter();
                              },
                            ),
                          ),
                          const VerticalDivider(width: 20),
                          DropdownButton<String>(
                            value: _selectedActivity,
                            underline: const SizedBox(),
                            items: ['All', 'Field Work', 'Conference', 'Report']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              _selectedActivity = val!;
                              _runFilter();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- TABULAR DATA ---
                Expanded(
                  child: SingleChildScrollView(
                    child: PaginatedDataTable(
                      header: const Text("Student Attendance Records"),
                      rowsPerPage: 10,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Student Name')),
                        DataColumn(label: Text('Activity')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Check-In')),
                        DataColumn(label: Text('Check-Out')),
                        DataColumn(label: Text('Photo')),
                        DataColumn(label: Text('Map')),
                      ],
                      source: AttendanceDataSource(_filteredLogs, context),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- DATA SOURCE FOR TABLE ---
class AttendanceDataSource extends DataTableSource {
  final List<Map<String, dynamic>> logs;
  final BuildContext context;

  AttendanceDataSource(this.logs, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= logs.length) return null;
    final log = logs[index];
    final profile = log['profiles'];

    return DataRow(
      cells: [
        DataCell(Text(profile['display_name'] ?? 'N/A')),
        DataCell(
          Chip(
            label: Text(log['activity_type']),
            visualDensity: VisualDensity.compact,
          ),
        ),
        DataCell(
          Text(
            DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime.parse(log['check_in_time'])),
          ),
        ),
        DataCell(
          Text(
            DateFormat('hh:mm a').format(DateTime.parse(log['check_in_time'])),
          ),
        ),
        DataCell(
          Text(
            log['check_out_time'] != null
                ? DateFormat(
                    'hh:mm a',
                  ).format(DateTime.parse(log['check_out_time']))
                : "Active",
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.image, color: Colors.indigo),
            onPressed: () => _showImageDialog(log['check_in_img_url']),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.location_on, color: Colors.redAccent),
            onPressed: () => _showMapDialog(log),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String? url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: url != null
            ? Image.network(url)
            : const Text("No image available"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showMapDialog(Map log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: 500,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(log['check_in_lat'], log['check_in_lng']),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(log['check_in_lat'], log['check_in_lng']),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                if (log['check_out_lat'] != null)
                  Marker(
                    point: LatLng(log['check_out_lat'], log['check_out_lng']),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => logs.length;
  @override
  int get selectedRowCount => 0;
}
