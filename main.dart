import 'dart:developer';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:time_table/models/Timing_model.dart';
import 'package:time_table/models/teacher_model.dart';
import 'package:time_table/widgets/fields/primary_type_ahead_field.dart';
import 'package:time_table/widgets/texts/primary_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rosary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'AXILAR Time Table'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var teachersRef = FirebaseDatabase.instance.ref("teachers");
  var timingsRef = FirebaseDatabase.instance.ref("timings");

  // var allTimingsList = List<TimingModel>.empty(growable: true);
  var allTimingsTableList = List<List<String>>.empty(growable: true).obs;

  var allTeachersSuggestions = List<Map>.empty(growable: true).obs;

  var selectedTeacherModel = TeacherModel().obs;

  var teacherTEController = TextEditingController();

  var uploadedMsg = "".obs;

  List<TimingModel> filterListByDay(List<TimingModel> timingsList, String day) {
    List<TimingModel> outputList =
        timingsList.where((o) => o.day == day).toList();
    return outputList;
  }

  String getClassName(String period) {
    var splitClassName = period.split("-");
    if (splitClassName.length == 2) {
      return splitClassName[1];
    }
    return "-";
  }

  List<String> getPeriodsList(List<TimingModel> dayList) {
    var allPeriodsList = ["-", "-", "-", "-", "-", "-", "-", "-"];
    if (dayList.isNotEmpty) {
      var period = dayList[0].period;
      var periodsList = period?.split(",");
      if (periodsList != null && periodsList.isNotEmpty) {
        for (var element in periodsList) {
          if (element.startsWith("P1")) {
            allPeriodsList[0] = getClassName(element);
          } else if (element.startsWith("P2")) {
            allPeriodsList[1] = getClassName(element);
          } else if (element.startsWith("P3")) {
            allPeriodsList[2] = getClassName(element);
          } else if (element.startsWith("P4")) {
            allPeriodsList[3] = getClassName(element);
          } else if (element.startsWith("P5")) {
            allPeriodsList[4] = getClassName(element);
          } else if (element.startsWith("P6")) {
            allPeriodsList[5] = getClassName(element);
          } else if (element.startsWith("P7")) {
            allPeriodsList[6] = getClassName(element);
          } else if (element.startsWith("P8")) {
            allPeriodsList[7] = getClassName(element);
          }
        }
      }
    }
    return allPeriodsList;
  }

  @override
  void initState() {
    super.initState();
    /*allTimingsList.addAll([
      TimingModel(code: "RS001", day: "TUE", period: "P1-V,P5-X1 A"),
      TimingModel(code: "RS001", day: "FRI", period: "P3-V,P4-X1 A"),
      TimingModel(code: "RS001", day: "WED", period: "P4-V,P2-X1 A"),
      TimingModel(code: "RS001", day: "THU", period: "P6-V,P8-X1 A"),
      TimingModel(code: "RS001", day: "MON", period: "P1-V,P2-X1 A"),
    ]);*/
    teachersRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value == null) return;
      final data = event.snapshot.value as List<Object?>;
      if (data.isNotEmpty) {
        final teachersList = List<Map>.empty(growable: true);
        for (var element in data) {
          if (element != null) {
            teachersList.add(element as Map);
          }
        }
        allTeachersSuggestions.value = teachersList;
      }
    });
  }

  setTimeTable(Map item) {
    var name = item["Name"];
    var code = item["Code"];
    if (name != null && code != null) {
      selectedTeacherModel.value = TeacherModel();

      teacherTEController.text = name;

      timingsRef
          .orderByChild("Code")
          .equalTo(code)
          .once()
          .then((DatabaseEvent event) {
        if (event.snapshot.value == null) {
          return;
        }

        var timingsList = List<TimingModel>.empty(growable: true);

        for (var element in event.snapshot.children) {
          timingsList.add(TimingModel.fromJson(element.value));
        }

        var daysList = ["MON", "TUE", "WED", "THU", "FRI"];

        allTimingsTableList.clear();

        for (var day in daysList) {
          var periodsList = filterListByDay(timingsList, day);
          var orderedList = List<String>.empty(growable: true);
          orderedList.add(day);
          orderedList.addAll(getPeriodsList(periodsList));
          allTimingsTableList.add(orderedList);
        }
        selectedTeacherModel.value = TeacherModel.fromJson(item);
      });
    }
  }

  List getTeachersSuggestionList(String q) {
    var filteredTeachersList = List<Map>.empty(growable: true);
    for (var element in allTeachersSuggestions) {
      var name = element["Name"];
      if (name != null &&
          name.toString().toLowerCase().contains(q.toLowerCase())) {
        filteredTeachersList.add(element);
      }
    }
    return filteredTeachersList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Obx(() {
        return SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed: () async {
                  uploadedMsg.value = "";

                  var result = await FilePicker.platform.pickFiles();

                  if (result != null) {
                    var path = result.files.single.path;
                    if (path != null) {
                      var bytes = File(path).readAsBytesSync();
                      var excel = Excel.decodeBytes(bytes);

                      for (var sheetName in excel.tables.keys) {
                        log("sheetName $sheetName");
                        if (sheetName == "Teachers" || sheetName == "Timings") {
                          var sheet = excel.tables[sheetName];
                          if (sheet != null) {
                            var rows = sheet.rows;
                            if (rows.isNotEmpty) {
                              // separate title row from the table rows
                              var titleRow = rows[0];
                              var data = List<Map<String, dynamic>>.empty(
                                  growable: true);
                              for (var row in rows.sublist(1)) {
                                var rowData = <String, dynamic>{};
                                for (var i = 0; i < row.length; i++) {
                                  var title = titleRow[i];
                                  var col = row[i];
                                  if (title != null && col != null) {
                                    rowData[title.value.toString()] =
                                        col.value.toString();
                                  } else {
                                    // todo throw exception
                                  }
                                }
                                data.add(rowData);
                              }
                              log("teachers -> $data");
                              if (sheetName == "Teachers") {
                                await teachersRef.set(data).then((value) {
                                  log("success");
                                }).onError((error, stackTrace) {
                                  log("failed to upload");
                                });
                              } else {
                                await timingsRef.set(data).then((value) {
                                  uploadedMsg.value =
                                      "Data uploaded successfully";
                                }).onError((error, stackTrace) {
                                  log("failed to upload");
                                  uploadedMsg.value = "Data upload failed";
                                });
                              }
                            } else {
                              // todo throw exception
                            }
                          } else {
                            // todo throw exception
                          }
                        } else {
                          // todo throw exception
                        }
                      }
                    }
                  } else {
                    // User canceled the picker
                  }
                },
                child: const Text(
                  "Update Teachers and Timings Data",
                ),
              ),
              Visibility(
                visible: uploadedMsg.isNotEmpty,
                child: const PrimaryText(
                  "* Data uploaded successfully",
                  fontColor: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: PrimaryTypeAheadField(
                  controller: teacherTEController,
                  label: "Type a teacher name",
                  suggestionsCallback: (pattern) async {
                    if (pattern.isNotEmpty) {
                      return getTeachersSuggestionList(pattern);
                    }
                    return allTeachersSuggestions.value;
                  },
                  onSuggestionSelected: (suggestion) async {
                    var item = suggestion as Map;
                    setTimeTable(item);
                  },
                  itemBuilder: (context, suggestion) {
                    var item = suggestion as Map;
                    return ListTile(
                      title: Text(
                        item["Name"] ?? "",
                      ),
                    );
                  },
                  isValid: true.obs,
                  errorMsg: "",
                ),
              ),
              Visibility(
                visible: selectedTeacherModel.value.code != null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    children: [
                      Image.network(
                        selectedTeacherModel.value.image ??
                            "https://www.pngarts.com/files/6/User-Avatar-in-Suit-PNG.png",
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.black),
                            left: BorderSide(color: Colors.black),
                            right: BorderSide(color: Colors.black),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            selectedTeacherModel.value.name ?? "-",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Table(
                        border: TableBorder.all(
                          width: 1,
                          color: Colors.black,
                        ),
                        children: [
                          const TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 1",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 2",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 3",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 4",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 5",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 6",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 7",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Period 8",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...allTimingsTableList.map((timings) {
                            return TableRow(children: [
                              for (var i = 0; i < timings.length; i++)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    timings[i],
                                    style: TextStyle(
                                      fontWeight: i == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                )
                            ]);
                          }).toList(),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
