// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:multiwordexpressionworkbench/fetchData/fetchSentenceItems.dart';
import 'package:multiwordexpressionworkbench/models/sentence_model.dart';

import '../models/project.dart';
import '../services/secureStorageService.dart';

Future<List<Project>> FetchProjectItems() async {
  var url = Uri.https(
      'www.cfilt.iitb.ac.in', 'annotation_tool_apis/project/get_project_list');
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
  var url = Uri.https(
      'www.cfilt.iitb.ac.in', 'annotation_tool_apis/user/$organizationName');
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

Future<void> assignUserToProject(int projectId, int userId) async {
  var url = Uri.https('www.cfilt.iitb.ac.in',
      'annotation_tool_apis/project/assign_user_to_project/$projectId');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "user_id": userId,
  });

  final response = await http.post(url, headers: headers, body: body);

  print(response);

  if (response.statusCode == 200) {
    print('User assigned successfully to project $projectId');
  } else {
    throw Exception('Failed to assign user to project $projectId');
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

Future<bool> isUserAssigned(int projectId) async {
  // Build the API endpoint
  var url = Uri.https('www.cfilt.iitb.ac.in',
      'annotation_tool_apis/project/is_user_assigned/$projectId');

  // Retrieve the JWT token from secure storage
  var token = await SecureStorage().readSecureData("jwtToken");

  // Set up the headers with the token
  var headers = {
    'Authorization': 'Bearer $token',
  };

  // Send the GET request
  final response = await http.get(url, headers: headers);

  // Check the response status and parse the result
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['is_assigned'] ??
        false; // Return true/false based on the response
  } else {
    // Handle errors by throwing an exception or logging the error
    throw Exception('Failed to check assignment status for project $projectId');
  }
}

Future<List<String>> searchAnnotations(String query, String? language) async {
  var url = Uri.https(
      'www.cfilt.iitb.ac.in', 'annotation_tool_apis/search_annotations', {
    'query': query,
    'language': language ?? '',
  });

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
  var url = Uri.https('www.cfilt.iitb.ac.in',
      'annotation_tool_apis/project/update_project_title/$projectId');
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
  var url = Uri.https('www.cfilt.iitb.ac.in',
      'annotation_tool_apis/annotation/search_sentences_by_annotation');

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
