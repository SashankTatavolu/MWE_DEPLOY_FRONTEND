// ignore_for_file: sized_box_for_whitespace

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:multiwordexpressionworkbench/fetchData/fetchSentenceItems.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import '../models/annotation_model.dart';
import '../models/project.dart';
import '../models/sentence_model.dart';
import '../services/annotationService.dart';
import 'loginPage.dart';
import 'package:pdfrx/pdfrx.dart';

class AnnotateSentencePage extends StatefulWidget {
  final List<Sentence> sentences;
  final Project project;

  const AnnotateSentencePage(
      {super.key, required this.sentences, required this.project});

  @override
  State<AnnotateSentencePage> createState() => _AnnotateSentencePageState();
}

class _AnnotateSentencePageState extends State<AnnotateSentencePage> {
  List<Annotation> annotationList = [];
  int selectedIndex = -1;
  TextEditingController? _controller;
  int currentPage = 0;
  final int sentencesPerPage = 6;
  bool isValidTextSelected = false;
  String selectedText = "";
  final List<String> _dropdownAnnotationValues = [
    "Noun Compound",
    "Reduplicated",
    "Idiom",
    "Compound Verb",
    "Complex Predicate"
  ];
  String? _selectedValue;
  bool unsavedChanges = false;
  AnnotationService annotationService = AnnotationService();
  String _selectedType = 'Multiword Expression';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _checkSelectedText(TextEditingController controller) {
    if (controller.selection.isValid) {
      String selectedText = controller.text
          .substring(controller.selection.start, controller.selection.end);
      if (selectedText.trim().split(RegExp(r'\s+')).length > 1) {
        print("Selected text: $selectedText");
        isValidTextSelected = true;
        setState(() {
          this.selectedText = selectedText;
        });
      } else {
        setState(() {
          isValidTextSelected = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = (widget.sentences.length / sentencesPerPage).ceil();
    final currentPageSentences = getCurrentPageSentences();

    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Column(
            children: [
              _buildProjectHeader(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMainContent(currentPageSentences, pages),
                  _buildAnnotationsSidebar(),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  List<Sentence> getCurrentPageSentences() {
    final startIndex = currentPage * sentencesPerPage;
    final endIndex =
        min(startIndex + sentencesPerPage, widget.sentences.length);
    return widget.sentences.getRange(startIndex, endIndex).toList();
  }

  Widget _buildMainContent(List<Sentence> currentPageSentences, int pages) {
    return Row(
      children: [
        Container(
          width: 900,
          height: 600,
          child: Column(
            children: [
              _buildSentenceList(currentPageSentences),
              isValidTextSelected
                  ? _buildAnnotationControls()
                  : _buildSelectTextPrompt(),
              _buildPaginationControls(pages),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnotationControls() {
    return Container(
      child: Column(
        children: [
          Container(
            child: Row(
              children: [
                Text("Annotation Type"),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Selected Text : $selectedText"),
              _buildDropdownAnnotation(),
              _buildAddButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRadioTile(String title) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        value: title,
        groupValue: _selectedType,
        onChanged: (String? value) {
          setState(() {
            _selectedType = value!;
          });
        },
      ),
    );
  }

  Widget _buildDropdownAnnotation() {
    return DropdownButton<String>(
      value: _selectedValue,
      hint: const Text("Select Annotation"),
      items: _dropdownAnnotationValues.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedValue = newValue;
        });
      },
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: _onAddButtonPressed,
      child: Text("Add"),
    );
  }

  void _onAddButtonPressed() {
    if (_selectedValue != null) {
      Annotation annotation = Annotation(
        wordPhrase: selectedText,
        annotation: _selectedValue!,
        sentenceId: widget
            .sentences[selectedIndex + (currentPage * sentencesPerPage)].id,
        projectId: widget.project.id,
      );
      print(annotation.toJson());
      setState(() {
        unsavedChanges = true;
        annotationList.add(annotation);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please Select Annotation")),
      );
    }
  }

  Widget _buildSelectTextPrompt() {
    return Text(
      "Select at least two words to Annotate",
      style: TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAnnotationsSidebar() {
    return Container(
      width: 400,
      height: 500,
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAnnotationsList(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAnnotationsList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(),
        ),
        child: ListView.builder(
          itemCount: annotationList.length,
          itemBuilder: (context, index) {
            return _buildAnnotationListItem(index);
          },
        ),
      ),
    );
  }

  Widget _buildAnnotationListItem(int index) {
    final annotation = annotationList[index];

    // Creating a TextEditingController for each list item
    final TextEditingController wordPhraseController =
        TextEditingController(text: annotation.wordPhrase);

    // Update wordPhraseController text when annotation.wordPhrase changes
    wordPhraseController.addListener(() {
      annotation.wordPhrase = wordPhraseController.text;
    });

    return ListTile(
      title: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: wordPhraseController,
              onSubmitted: (newValue) {
                // Update the wordPhrase directly
                setState(() {
                  annotation.wordPhrase = newValue;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              annotation.annotation,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      leading: Text(
        (index + 1).toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () => _deleteAnnotation(index),
      ),
    );
  }

  void _deleteAnnotation(int index) {
    setState(() {
      annotationList.removeAt(index);
    });
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubmitButton(),
        _buildResetButton(),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _handleSubmit,
      child: const Text("Submit"),
    );
  }

  void _handleSubmit() async {
    bool submitStatus = await annotationService.addAnnotation(annotationList);
    if (submitStatus) {
      setState(() {
        unsavedChanges = false;
        // Assuming annotationList[0] is not out of bounds; consider handling potential empty list or refactor logic accordingly.
        widget.sentences[selectedIndex + (currentPage * sentencesPerPage)]
            .isAnnotated = true;
        annotationList = [];
      });
    } else {
      // Handle failure case
    }
  }

  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: _handleReset,
      child: const Text("Reset"),
    );
  }

  void _handleReset() async {
    setState(() {
      annotationList = [];
    });
  }

  Future<void> _logout(BuildContext context) async {
    await SecureStorage().deleteSecureData('jwtToken');
    // Navigate to Login Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget _buildProjectHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [Text(widget.project.title), Text(widget.project.language)],
      );

  Widget _buildSentenceList(List<Sentence> sentences) => Expanded(
        child: ListView.builder(
          itemCount: sentences.length,
          itemBuilder: (context, index) {
            return _buildSentenceTile(index, sentences);
          },
        ),
      );

  Widget _buildSentenceTile(int index, List<Sentence> sentences) {
    final isSelected = selectedIndex == index;
    final sentence = sentences[index];
    return ListTile(
      onTap: () async {
        if (unsavedChanges) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Please submit the annotations, before moving on to next sentence")));
        } else {
          List<Annotation> existingAnnotationList =
              await annotationService.fetchAnnotations(sentence.id);
          print(existingAnnotationList);
          setState(() {
            selectedIndex = index;
            isValidTextSelected = false;
            _controller?.text = sentence.content;
            annotationList = existingAnnotationList;
          });
        }
      },
      leading: sentence.isAnnotated == true
          ? const Icon(
              Icons.done_outline_outlined,
              color: Colors.green,
            )
          : null,
      title: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
          color: isSelected ? Colors.yellow : Colors.grey[300],
        ),
        padding: const EdgeInsets.all(8),
        child: isSelected
            ? TextField(
                decoration: const InputDecoration(border: InputBorder.none),
                controller: _controller,
                readOnly: true,
                showCursor: false,
                autofocus: true,
                maxLines: null, // Allows multi-line input
              )
            : Text(
                sentence.content,
                style: const TextStyle(fontSize: 16.5),
                maxLines: null, // Allows wrapping to multiple lines
              ),
      ),
      trailing: selectedIndex == index
          ? ElevatedButton(
              onPressed: () {
                _checkSelectedText(_controller!);
              },
              child: Text("Annotate"),
            )
          : null,
    );
  }

  Widget _buildPaginationControls(int pages) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentPage > 0
                ? () => setState(() {
                      currentPage--;
                    })
                : null,
          ),
          Text('Page ${currentPage + 1} of $pages'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentPage < pages - 1
                ? () => setState(() {
                      currentPage++;
                    })
                : null,
          ),
        ],
      );

  void _showPdf(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("PDF Content"),
          content: SizedBox(
            width: 1000,
            height: 600,
            child: PdfViewer.asset(
                'assets/files/USER_Guidelines.pdf'), // Update path as necessary
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPDF(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("PDF Content"),
          content: SizedBox(
            width: 1000,
            height: 600,
            child: PdfViewer.asset(
                'assets/files/annotation_guidelines.pdf'), // Update path as necessary
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    // Clear any existing user data if needed (optional)

    // Navigate to the login page and remove all previous routes from the stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false, // This removes all previous routes
    );
  }

  AppBar _buildAppBar() => AppBar(
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Navigate back to the ProjectsPage
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Image.asset("images/logo.png", fit: BoxFit.contain),
            ),
          ],
        ),
        toolbarHeight: 100,
        leadingWidth:
            400, // Adjust leading width to accommodate the back button
        backgroundColor: Colors.blue[100],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _showPdf(context);
              },
              child: const Text("Show User Guidelines"),
            ),
            const Spacer(),
            const Text('Multiword Expression Workbench'),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                _showPDF(context);
              },
              child: const Text("Show Annotation Guidelines"),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                _handleLogout(context);
              },
              child: const Text("Log Out"),
            ),
          ),
          // Search button added to AppBar
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
      );

  void _showSearchPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? language;
        List<Map<String, dynamic>> results = [];
        bool isLoading = false;
        String? errorMessage;

        // Function to perform the search and update the UI
        Future<void> performSearch() async {
          try {
            isLoading = true;
            errorMessage = null;
            results = await searchAnnotationsWithResults(query, language);
            isLoading = false;

            if (results.isEmpty) {
              errorMessage = 'No annotations found matching the criteria.';
            }
          } catch (e) {
            isLoading = false;
            errorMessage = 'An error occurred while searching: $e';
          }
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Search Annotations'),
              content: Container(
                width: 400, // Set the desired width for the dialog
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row for search inputs: text field and dropdown filter side by side
                    Row(
                      children: [
                        // Word phrase text field
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              query = value;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Search Query',
                            ),
                          ),
                        ),
                        const SizedBox(
                            width: 10), // Space between text field and dropdown
                        // Language filter dropdown
                        DropdownButton<String>(
                          value: language,
                          onChanged: (String? newValue) {
                            setState(() {
                              language = newValue;
                            });
                          },
                          hint: const Text("Select Language"),
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator()),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                    if (results.isNotEmpty) ...[
                      const Text(
                        'Search Results:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      // Displaying the results in a table
                      Expanded(
                        child: SingleChildScrollView(
                          child: Table(
                            border: TableBorder.all(),
                            columnWidths: const {
                              0: FixedColumnWidth(120),
                              1: FixedColumnWidth(180),
                              2: FixedColumnWidth(100),
                            },
                            children: [
                              // Header row for the table
                              TableRow(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Word/Phrase',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Sentence',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Annotation',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              // Populate the table rows with search results
                              for (var annotation in results)
                                TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(annotation['word_phrase']),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(annotation['sentence_text']),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(annotation['annotation']),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    setState(() {
                      isLoading = true;
                      results.clear();
                      errorMessage = null;
                    });
                    await performSearch();
                    setState(() {
                      isLoading = false;
                    });
                  },
                  child: const Text('Search'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
