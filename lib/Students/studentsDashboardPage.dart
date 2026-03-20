import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AttendanceMainPage extends StatelessWidget {
  const AttendanceMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Attendance Portal"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_location), text: "Track"),
              Tab(icon: Icon(Icons.history), text: "History"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [AttendanceTrackerTab(), AttendanceLogsView()],
        ),
      ),
    );
  }
}

// --- TAB 1: TRACKER LOGIC ---
class AttendanceTrackerTab extends StatefulWidget {
  const AttendanceTrackerTab({super.key});

  @override
  State<AttendanceTrackerTab> createState() => _AttendanceTrackerTabState();
}

class _AttendanceTrackerTabState extends State<AttendanceTrackerTab> {
  final supabase = Supabase.instance.client;
  String _selectedActivity = 'Field Work';
  bool _isCheckIn = true;
  String? _activeRecordId;
  bool _isLoading = false;

  Future<void> _handleAction() async {
    // 1. Check/Request Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Open Camera Directly
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera, // Forces the camera UI
      preferredCameraDevice: CameraDevice.front, // Suggested for attendance
      imageQuality: 25, // Compress to save Supabase storage space
    );

    if (photo == null) return; // User cancelled

    setState(() => _isLoading = true);

    try {
      // 3. Get Location
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Upload Photo
      final bytes = await photo.readAsBytes();
      final userId = supabase.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await supabase.storage
          .from('attendance')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imgUrl = supabase.storage.from('attendance').getPublicUrl(path);

      if (_isCheckIn) {
        final res = await supabase
            .from('attendance_logs')
            .insert({
              'user_id': userId,
              'activity_type': _selectedActivity,
              'check_in_lat': pos.latitude,
              'check_in_lng': pos.longitude,
              'check_in_img_url': imgUrl,
            })
            .select()
            .single();

        setState(() {
          _activeRecordId = res['id'];
          _isCheckIn = false;
        });
      } else {
        await supabase
            .from('attendance_logs')
            .update({
              'check_out_time': DateTime.now().toIso8601String(),
              'check_out_lat': pos.latitude,
              'check_out_lng': pos.longitude,
              'check_out_img_url': imgUrl,
              'is_active': false,
            })
            .eq('id', _activeRecordId!);

        setState(() {
          _activeRecordId = null;
          _isCheckIn = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCheckIn ? "Checked Out!" : "Checked In!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<String>(
            value: _selectedActivity,
            onChanged: _isCheckIn
                ? (v) => setState(() => _selectedActivity = v!)
                : null,
            items: [
              'Report',
              'Conference',
              'Field Work',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          ),
          const SizedBox(height: 40),
          _isLoading
              ? const CircularProgressIndicator()
              : InkWell(
                  onTap: _handleAction,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundColor: _isCheckIn ? Colors.green : Colors.red,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white),
                        const SizedBox(height: 10),
                        Text(
                          _isCheckIn ? "CHECK IN" : "CHECK OUT",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// --- TAB 2: LOGS VIEW ---
class AttendanceLogsView extends StatelessWidget {
  const AttendanceLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('attendance_logs')
          .stream(primaryKey: ['id'])
          .order('check_in_time'),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final logs = snapshot.data!;
        if (logs.isEmpty) return const Center(child: Text("No records yet."));

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, i) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  logs[i]['check_in_img_url'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.person),
                ),
              ),
              title: Text("${logs[i]['activity_type']}"),
              subtitle: Text(
                "In: ${DateTime.parse(logs[i]['check_in_time']).toLocal().toString().split('.')[0]}",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.map, color: Colors.blue),
                onPressed: () => _openMap(context, logs[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMap(BuildContext context, Map log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(log['check_in_lat'], log['check_in_lng']),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.joshua.socialworkFieldWork',
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
}
