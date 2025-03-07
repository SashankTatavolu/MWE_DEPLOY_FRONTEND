// ignore_for_file: file_names, library_private_types_in_public_api, avoid_print, use_bontext_synchronously, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multiwordexpressionworkbench/services/annotationService.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/annotateSentencePage.dart';
import 'package:multiwordexpressionworkbench/ui/home_page.dart';
import 'package:multiwordexpressionworkbench/ui/overlays/addProjectOverlay.dart';
import '../fetchData/fetchProjectItems.dart';
import '../fetchData/fetchSentenceItems.dart';
import '../models/project.dart';
import '../models/sentence_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  _ProjectsPageState createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Project> projects = [];
  List<Sentence> sentences = [];
  int currentPage = 0;
  final int itemsPerPage = 5;
  final AnnotationService annotationService = AnnotationService();
  final secureStorage = FlutterSecureStorage();
  Map<int, int> totalSentencesMap =
      {}; // Map to store total sentences for each project
  Map<int, int> annotatedSentencesMap = {};
  bool isLoading = true;
  String? userRole;

  Future<void> fetchProjectItems() async {
    try {
      final fetchedProjects = await FetchProjectItems();
      setState(() {
        projects = fetchedProjects;
        isLoading = true;
      });
      await fetchAllSentenceCounts();
    } catch (e) {
      print("Error fetching projects: $e");
    }
  }

  Future<void> fetchAllSentenceCounts() async {
    // Fetch total and annotated sentence counts for all projects in parallel
    final fetchTasks = projects.map((project) async {
      final totalSentences = await fetchTotalSentences(project.id);
      final annotatedSentences = await fetchAnnotatedSentences(project.id);
      setState(() {
        totalSentencesMap[project.id] = totalSentences;
        annotatedSentencesMap[project.id] = annotatedSentences;
      });
    }).toList();

    // Wait for all tasks to complete
    await Future.wait(fetchTasks);

    // After fetching all sentence data, set loading to false
    setState(() {
      isLoading = false;
    });
  }

  Future<void> deleteProject(int projectId) async {
    bool success = await annotationService.deleteProject(projectId);
    if (success) {
      await fetchProjectItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project deleted successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete project")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProjectItems();
    fetchAllSentenceCounts();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    // Retrieve the user's role from SecureStorage
    String? role = await SecureStorage().readSecureData('role');
    setState(() {
      userRole = role; // Set the role in the state
    });
  }

  void _showOverlay(BuildContext context) async {
    OverlayState overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: AddProjectOverlay(
          onCancel: () async {
            await fetchProjectItems();
            overlayEntry.remove();
            setState(() {});
          },
        ),
      ),
    );
    overlayState.insert(overlayEntry);
  }

  Future<void> _logout(BuildContext context) async {
    // Navigate to Login Page
    await SecureStorage().deleteSecureData('jwtToken');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  void _showSearchPopup(BuildContext context) {
    String query = '';
    String? language;
    List<Map<String, dynamic>> searchResults = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.all(
                  20), // Adding some padding for better appearance
              insetPadding: EdgeInsets.symmetric(
                  horizontal: 30), // Increasing width of the popup
              title: const Text('Search Multi Word Expression Type'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row for Search Bar and Language Filter side by side
                  Row(
                    children: [
                      // Search Bar
                      Expanded(
                        flex: 3, // Adjust the space ratio for search bar
                        child: TextField(
                          onChanged: (value) {
                            query = value;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Search MWE Type',
                          ),
                        ),
                      ),
                      const SizedBox(
                          width:
                              16), // Adding space between search bar and dropdown
                      // Language Filter Dropdown
                      Expanded(
                        flex: 2, // Adjust the space ratio for language filter
                        child: DropdownButton<String>(
                          value: language,
                          onChanged: (String? newValue) {
                            setState(() {
                              language = newValue;
                            });
                          },
                          hint: const Text("Select Language"),
                          isExpanded: true,
                          items: <String>[
                            'Bangla',
                            'Maithili',
                            'Konkani',
                            'Marathi',
                            'Manipuri',
                            'Nepali',
                            'Bodo',
                            'Assamee',
                            'Hindi'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                      height:
                          20), // Space between the search/filter section and results

                  // Show the search results as a table
                  if (searchResults.isNotEmpty)
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('Word Phrase')),
                        DataColumn(label: Text('Sentence')),
                      ],
                      rows: searchResults.map((result) {
                        return DataRow(cells: [
                          DataCell(Text(result['word_phrase'] ?? '')),
                          DataCell(Text(result['sentence_text'] ?? '')),
                        ]);
                      }).toList(),
                    ),
                ],
              ),
              actions: <Widget>[
                // Search Button
                TextButton(
                  onPressed: () async {
                    // Call the search API and update the results
                    try {
                      final results = await searchAnnotationsWithLanguageFilter(
                          query, language);
                      setState(() {
                        searchResults = results;
                      });
                    } catch (e) {
                      print("Error fetching annotations: $e");
                    }
                  },
                  child: const Text('Search'),
                ),
                // Cancel Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Project project) {
    final TextEditingController titleController =
        TextEditingController(text: project.title);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Project Title'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Project Title',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () async {
                String newTitle = titleController.text.trim();
                if (newTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title cannot be empty')),
                  );
                  return;
                }

                try {
                  // Call the API to update the title
                  await updateProjectTitle(project.id, newTitle);

                  // Update the project in the local list
                  setState(() {
                    project.title = newTitle;
                  });

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project title updated!')),
                  );

                  Navigator.of(context).pop(); // Close the dialog
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (projects.length / itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        leading: Image.asset("images/logo.png"),
        toolbarHeight: 100,
        leadingWidth: 300,
        backgroundColor: Colors.grey[300],
        title: const Align(
          alignment: Alignment.center,
          child: Text('Multiword Expression Workbench'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () => _logout(context),
              child: const Text("Log Out"),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(20.0),
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _showSearchPopup(context);
              },
            ),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(40),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Projects",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: userRole == 'Admin'
                      ? () {
                          _showOverlay(context);
                        }
                      : null, // Disable button if user is not admin
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.disabled)) {
                          return Colors.grey; // Disabled button color
                        }
                        return Colors.green; // Normal color
                      },
                    ),
                  ),
                  child: const Text(
                    "+ Add Project",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: isLoading // Show loading indicator until data is loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: itemsPerPage,
                      itemBuilder: (context, index) {
                        if (index + currentPage * itemsPerPage <
                            projects.length) {
                          final projectIndex =
                              index + currentPage * itemsPerPage;
                          final project = projects[projectIndex];

                          // If the data for this project is not yet loaded, return an empty container
                          if (!totalSentencesMap.containsKey(project.id) ||
                              !annotatedSentencesMap.containsKey(project.id)) {
                            return Container(); // No data yet, no loading indicator here
                          }

                          int totalSentences =
                              totalSentencesMap[project.id] ?? 0;
                          int annotatedCount =
                              annotatedSentencesMap[project.id] ?? 0;

                          return Card(
                            child: ListTile(
                              onTap: () async {
                                sentences =
                                    await FetchSentenceItems(project.id);
                                Get.to(AnnotateSentencePage(
                                    sentences: sentences, project: project));
                              },
                              title: Text(project.title),
                              subtitle: Text(
                                  'Language: ${project.language}\nDescription: ${project.description}'),
                              trailing: SizedBox(
                                width: 450,
                                height: 50,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$annotatedCount / $totalSentences',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (String result) {},
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'Assign User',
                                          child: const Text('Assign User'),
                                          onTap: () async {
                                            try {
                                              final organizationName =
                                                  await SecureStorage()
                                                      .readSecureData(
                                                          'organization');
                                              List<Map<String, dynamic>> users =
                                                  await fetchUsersByOrganization(
                                                      organizationName);

                                              if (users.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'No users found in the organization.')),
                                                );
                                                return;
                                              }

                                              // Fetch sentences of the project
                                              List<int> sentenceIds =
                                                  await fetchSentenceIds(
                                                      project.id);
                                              if (sentenceIds.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'No sentences found for this project.')),
                                                );
                                                return;
                                              }

                                              // Fetch assigned and unassigned sentences
                                              Map<String, List<int>>
                                                  sentenceStatus =
                                                  await fetchSentenceStatus(
                                                      project.id);
                                              List<int> unassignedSentences =
                                                  sentenceStatus[
                                                      "unassigned_sentences"]!;

                                              if (unassignedSentences.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'All sentences are already assigned.')),
                                                );
                                                return;
                                              }

                                              // Show dialog to select users and assign sentences
                                              await showDialog(
                                                context: context,
                                                builder: (context) {
                                                  Set<int> selectedUserIds =
                                                      {}; // Selected user IDs
                                                  Set<int> selectedSentenceIds =
                                                      {}; // Selected sentence IDs

                                                  return StatefulBuilder(
                                                    builder:
                                                        (context, setState) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Assign Sentences to Users'),
                                                        content: SizedBox(
                                                          height: 400,
                                                          width: 600,
                                                          child: Column(
                                                            children: [
                                                              // User selection
                                                              const Text(
                                                                  "Select Users"),
                                                              Expanded(
                                                                child: ListView
                                                                    .builder(
                                                                  itemCount: users
                                                                      .length,
                                                                  itemBuilder:
                                                                      (context,
                                                                          index) {
                                                                    final user =
                                                                        users[
                                                                            index];
                                                                    return CheckboxListTile(
                                                                      title: Text(
                                                                          user[
                                                                              'name']),
                                                                      value: selectedUserIds
                                                                          .contains(
                                                                              user['id']),
                                                                      onChanged:
                                                                          (bool?
                                                                              isSelected) {
                                                                        setState(
                                                                            () {
                                                                          if (isSelected ==
                                                                              true) {
                                                                            selectedUserIds.add(user['id']);
                                                                          } else {
                                                                            selectedUserIds.remove(user['id']);
                                                                          }
                                                                        });
                                                                      },
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 10),

                                                              // Sentence selection
                                                              const Text(
                                                                  "Select Sentences"),
                                                              Expanded(
                                                                child: ListView
                                                                    .builder(
                                                                  itemCount:
                                                                      unassignedSentences
                                                                          .length,
                                                                  itemBuilder:
                                                                      (context,
                                                                          index) {
                                                                    final sentenceId =
                                                                        unassignedSentences[
                                                                            index];
                                                                    return CheckboxListTile(
                                                                      title: Text(
                                                                          "Sentence ID: $sentenceId"),
                                                                      value: selectedSentenceIds
                                                                          .contains(
                                                                              sentenceId),
                                                                      onChanged:
                                                                          (bool?
                                                                              isSelected) {
                                                                        setState(
                                                                            () {
                                                                          if (isSelected ==
                                                                              true) {
                                                                            selectedSentenceIds.add(sentenceId);
                                                                          } else {
                                                                            selectedSentenceIds.remove(sentenceId);
                                                                          }
                                                                        });
                                                                      },
                                                                    );
                                                                  },
                                                                ),
                                                              ),

                                                              // Submit Button
                                                              ElevatedButton(
                                                                onPressed:
                                                                    () async {
                                                                  if (selectedUserIds
                                                                          .isEmpty ||
                                                                      selectedSentenceIds
                                                                          .isEmpty) {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text('Select at least one user and sentence.'),
                                                                      ),
                                                                    );
                                                                    return;
                                                                  }

                                                                  // Assign selected sentences to users
                                                                  List<Map<String, dynamic>>
                                                                      assignments =
                                                                      [];
                                                                  for (int userId
                                                                      in selectedUserIds) {
                                                                    assignments
                                                                        .add({
                                                                      "user_id":
                                                                          userId,
                                                                      "sentence_ids":
                                                                          selectedSentenceIds
                                                                              .toList(),
                                                                    });
                                                                  }

                                                                  await assignSentencesToUsers(
                                                                      project
                                                                          .id,
                                                                      assignments);

                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(); // Close dialog
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                          'Sentences assigned successfully!'),
                                                                    ),
                                                                  );
                                                                },
                                                                child: const Text(
                                                                    'Submit'),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to assign sentences: $e')),
                                              );
                                            }
                                          },
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'Download File',
                                          child: const Text('Download File'),
                                          onTap: () async {
                                            // Displaying a dialog or action sheet for file type selection
                                            String? selectedFileType =
                                                await showDialog<String>(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Select File Type'),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        title:
                                                            const Text('TXT'),
                                                        onTap: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop('TXT'),
                                                      ),
                                                      ListTile(
                                                        title:
                                                            const Text('XML'),
                                                        onTap: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop('XML'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );

                                            // Handle download based on user selection
                                            if (selectedFileType != null) {
                                              try {
                                                if (selectedFileType == 'TXT') {
                                                  await annotationService
                                                      .downloadAnnotationsTXT(
                                                          project.id,
                                                          project.title);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'TXT file downloaded successfully.'),
                                                    ),
                                                  );
                                                } else if (selectedFileType ==
                                                    'XML') {
                                                  await annotationService
                                                      .downloadAnnotationsXML(
                                                          project.id,
                                                          project.title);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'XML file downloaded successfully.'),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Failed to download $selectedFileType file: $e'),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'Edit',
                                          child: const Text('Edit'),
                                          onTap: () {
                                            Future.delayed(
                                              Duration.zero,
                                              () => _showEditDialog(
                                                  context, project),
                                            );
                                          },
                                        ),
                                      ],
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () async {
                                        bool? confirm = await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title:
                                                  const Text('Delete Project'),
                                              content: const Text(
                                                  'Are you sure you want to delete this project?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (confirm == true) {
                                          await deleteProject(project.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Container();
                        }
                      },
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: currentPage > 0
                      ? () {
                          setState(() {
                            currentPage--;
                          });
                        }
                      : null,
                ),
                ...List<Widget>.generate(totalPages, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${index + 1}',
                        style: (index == currentPage)
                            ? const TextStyle(
                                color: Colors.blue, fontWeight: FontWeight.bold)
                            : null,
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            currentPage++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
