// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:multiwordexpressionworkbench/fetchData/fetchSentenceItems.dart';
import 'package:multiwordexpressionworkbench/models/sentence_model.dart';

import '../models/project.dart';
import '../services/secureStorageService.dart';

Future<List<Project>> FetchProjectItems() async {
  var url = Uri.parse('http://localhost:5000/project/get_project_list');
  var token = await SecureStorage().readSecureData("jwtToken");

  var header = {
    'Authorization': 'Bearer $token',
  };

  final response = await http.get(
    url,
    headers: header,
  );

  print(response);

  if (response.statusCode == 200) {
    final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
    return parsed.map<Project>((json) => Project.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load project items');
  }
}

Future<List<Map<String, dynamic>>> fetchUsersByOrganization(
    String organizationName) async {
  var url =
      Uri.parse('http://localhost:5000/user/organisation/$organizationName');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
  };

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    final List<dynamic> parsed = json.decode(response.body);
    print(response.body);

    // Ensure the response is a list of maps with 'id' and 'name'
    return parsed
        .map((user) => {
              'id': user['id'],
              'name': user['name'],
            })
        .toList();
  } else {
    throw Exception('Failed to load users for organization $organizationName');
  }
}

Future<void> assignSentencesToUsers(
    int projectId, List<Map<String, dynamic>> assignments) async {
  var url = Uri.parse('http://localhost:5000/sentence/assign_sentences');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "project_id": projectId,
    "assignments": assignments, // List of {user_id, sentence_ids}
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Sentences assigned successfully for project $projectId');
    } else {
      print('Failed to assign sentences: ${response.body}');
      throw Exception('Failed to assign sentences');
    }
  } catch (e) {
    print('Error assigning sentences: $e');
    throw Exception('Error occurred while assigning sentences');
  }
}

Future<List<int>> fetchSentenceIds(int projectId) async {
  var url = Uri.parse('http://localhost:5000/sentence/get_sentence_ids');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "project_id": projectId,
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    List<int> sentenceIds = List<int>.from(jsonResponse["sentence_ids"]);
    return sentenceIds;
  } else {
    throw Exception('Failed to fetch sentence IDs for project $projectId');
  }
}

Future<List<int>> fetchAssignedSentenceIds() async {
  var url =
      Uri.parse('http://localhost:5000/sentence/check_assigned_sentences');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    if (jsonResponse.containsKey("assigned_sentence_ids")) {
      List<int> assignedSentenceIds =
          List<int>.from(jsonResponse["assigned_sentence_ids"]);
      return assignedSentenceIds;
    }
    return [];
  } else {
    throw Exception('Failed to fetch assigned sentence IDs');
  }
}

Future<Map<String, List<int>>> fetchSentenceStatus(int projectId) async {
  var url = Uri.parse('http://localhost:5000/sentence/get_sentence_status');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "project_id": projectId,
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    return {
      "assigned_sentences": List<int>.from(jsonResponse["assigned_sentences"]),
      "unassigned_sentences":
          List<int>.from(jsonResponse["unassigned_sentences"]),
    };
  } else {
    throw Exception('Failed to fetch sentence status for project $projectId');
  }
}

Future<int> fetchAnnotatedSentences(int projectId) async {
  // Replace this with your actual data-fetching logic
  List<Sentence> sentences = await FetchSentenceItems(projectId);
  return sentences.where((sentence) => sentence.isAnnotated == true).length;
}

Future<int> fetchTotalSentences(int projectId) async {
  // Fetch the sentences for the project (you can use your existing method to fetch sentences)
  List<Sentence> sentences = await FetchSentenceItems(projectId);
  return sentences.length; // Return the total number of sentences
}

Future<List<String>> searchAnnotations(String query, String? language) async {
  var url = Uri.parse(
    'http://localhost:5000/search_annotations',
  ).replace(queryParameters: {
    'query': query,
    'language': language ?? '',
  });
  ;

  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      return data
          .map((annotation) => annotation['annotation'] as String)
          .toList();
    } else {
      return []; // Return empty list if no annotations found
    }
  } else {
    throw Exception('Failed to search annotations');
  }
}

Future<void> updateProjectTitle(int projectId, String newTitle) async {
  var url = Uri.parse(
      'http://localhost:5000/project/update_project_title/$projectId');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    'title': newTitle,
  });

  final response = await http.put(
    url,
    headers: headers,
    body: body,
  );

  if (response.statusCode == 200) {
    print('Project title updated successfully');
  } else {
    print('Failed to update project title: ${response.body}');
    throw Exception('Failed to update project title');
  }
}

Future<List<Map<String, dynamic>>> searchAnnotationsWithLanguageFilter(
    String annotationText, String? language) async {
  var url = Uri.parse(
      'http://localhost:5000/annotation/search_sentences_by_annotation');

  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // Construct the request body
  var body = jsonEncode({
    'annotation_text': annotationText,
    'language': language ?? '', // Send empty string if no language is selected
  });

  // Send the POST request with body
  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      return data.map((result) {
        return {
          'word_phrase': result['word_phrase'],
          'sentence_text': result['sentence_text'],
        };
      }).toList();
    } else {
      return []; // Return empty list if no results found
    }
  } else {
    throw Exception('Failed to search annotations');
  }
}

Future<bool> registerUser(String name, String email, String password,
    String language, String role, String organisation) async {
  var url = Uri.parse('http://localhost:5000/user/register');
  var body = {
    "name": name,
    "email": email,
    "password": password,
    "language": language,
    "role": role,
    "organisation": organisation
  };

  String bodyJson = jsonEncode(body);

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: bodyJson,
  );

  if (response.statusCode == 200) {
    String jsonString = response.body;
    Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

    // Save user details securely if needed
    await SecureStorage()
        .writeSecureData('user_id', jsonResponse['id'].toString());
    await SecureStorage().writeSecureData('user_email', jsonResponse['email']);
    await SecureStorage().writeSecureData('user_name', jsonResponse['name']);

    return true;
  } else {
    return false;
  }
}
