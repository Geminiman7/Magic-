import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  await Hive.openBox('lectures');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecture Reminder',
      home: LecturePage(),
    );
  }
}

class LecturePage extends StatefulWidget {
  @override
  _LecturePageState createState() => _LecturePageState();
}

class _LecturePageState extends State<LecturePage> {
  final _box = Hive.box('lectures');
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final _lecturerController = TextEditingController();
  final _courseController = TextEditingController();
  final _venueController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings();
    _flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _scheduleNotifications(String title, DateTime lectureTime) async {
    final android = AndroidNotificationDetails('lecture_channel', 'Lecture Reminders',
        importance: Importance.max, priority: Priority.high);
    final ios = DarwinNotificationDetails();
    final platform = NotificationDetails(android: android, iOS: ios);

    for (int minutesBefore in [45, 30, 15]) {
      final scheduledTime = lectureTime.subtract(Duration(minutes: minutesBefore));
      if (scheduledTime.isAfter(DateTime.now())) {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          lectureTime.millisecondsSinceEpoch + minutesBefore,
          "Upcoming Lecture",
          "$title starts in $minutesBefore minutes",
          scheduledTime,
          platform,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    }
  }

  void _addLecture() {
    if (_selectedDate == null || _selectedTime == null) return;

    final lectureDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final data = {
      'lecturer': _lecturerController.text,
      'course': _courseController.text,
      'venue': _venueController.text,
      'datetime': lectureDateTime.toIso8601String(),
    };

    _box.add(data);
    _scheduleNotifications(_courseController.text, lectureDateTime);

    _lecturerController.clear();
    _courseController.clear();
    _venueController.clear();
    _selectedDate = null;
    _selectedTime = null;
    setState(() {});
  }

  void _deleteLecture(int index, DateTime dateTime) {
    for (int minutesBefore in [45, 30, 15]) {
      _flutterLocalNotificationsPlugin.cancel(dateTime.millisecondsSinceEpoch + minutesBefore);
    }
    _box.deleteAt(index);
    setState(() {});
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lecture Reminder")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(controller: _lecturerController, decoration: InputDecoration(labelText: "Lecturer")),
            TextField(controller: _courseController, decoration: InputDecoration(labelText: "Course Title")),
            TextField(controller: _venueController, decoration: InputDecoration(labelText: "Venue")),
            Row(
              children: [
                TextButton(onPressed: _pickDate, child: Text("Pick Date")),
                Text(_selectedDate == null ? "No Date" : DateFormat.yMd().format(_selectedDate!)),
              ],
            ),
            Row(
              children: [
                TextButton(onPressed: _pickTime, child: Text("Pick Time")),
                Text(_selectedTime == null ? "No Time" : _selectedTime!.format(context)),
              ],
            ),
            ElevatedButton(onPressed: _addLecture, child: Text("Add Lecture")),
            SizedBox(height: 20),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _box.listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) return Text("No lectures added.");
                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final item = box.getAt(index);
                      final dt = DateTime.parse(item['datetime']);
                      return ListTile(
                        title: Text("${item['course']} at ${item['venue']}"),
                        subtitle: Text("By ${item['lecturer']} on ${DateFormat.yMd().add_jm().format(dt)}"),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteLecture(index, dt),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
