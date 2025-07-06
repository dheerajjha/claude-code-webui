# Claude Code Web UI - API Documentation

A RESTful API for the Claude Code Web UI backend that provides streaming AI chat functionality, project management, and conversation history.

## Base Configuration

- **Base URL**: `http://localhost:8080` (configurable via PORT environment variable)
- **Content-Type**: `application/json` for POST requests
- **CORS**: Enabled for all origins
- **Authentication**: None required

## Flutter/Mobile Integration

This API is designed to be mobile-friendly with considerations for:
- Streaming responses using NDJSON format
- Request abort functionality for network management
- Session continuity for conversation flow
- Project-based working directory support

## API Endpoints

### 1. Chat API

#### POST `/api/chat`

Sends a message to Claude AI and receives streaming responses.

**Request Body**:
```json
{
  "message": "Your message to Claude",
  "requestId": "unique-request-identifier",
  "sessionId": "optional-session-id-for-continuity",
  "allowedTools": ["optional", "array", "of", "tool", "names"],
  "workingDirectory": "/optional/project/path"
}
```

**Request Fields**:
- `message` (string, required): The user's message or command
- `requestId` (string, required): Unique identifier for request tracking and abort functionality
- `sessionId` (string, optional): Session ID for conversation continuity within the same chat session
- `allowedTools` (array, optional): Array of tool names that Claude is allowed to use
- `workingDirectory` (string, optional): Project directory path for Claude execution context

**Response**:
- **Content-Type**: `application/x-ndjson`
- **Stream Format**: Newline-delimited JSON objects

**Stream Response Types**:
```json
{
  "type": "claude_json",
  "data": { /* Claude SDK message object */ }
}
```
```json
{
  "type": "error",
  "error": "Error message string"
}
```
```json
{
  "type": "done"
}
```
```json
{
  "type": "aborted"
}
```

**Example Usage**:
```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello Claude, help me debug this code",
    "requestId": "req-123",
    "sessionId": "session-456",
    "workingDirectory": "/path/to/my/project"
  }'
```

### 2. Abort Request

#### POST `/api/abort/:requestId`

Aborts an ongoing chat request by its request ID.

**URL Parameters**:
- `requestId` (string): The request ID to abort

**Response**:
```json
{
  "success": true,
  "message": "Request aborted"
}
```

**Error Response**:
```json
{
  "error": "Request not found or already completed"
}
```

**Example Usage**:
```bash
curl -X POST http://localhost:8080/api/abort/req-123
```

### 3. Projects Management

#### GET `/api/projects`

Retrieves list of available project directories from Claude configuration.

**Response**:
```json
{
  "projects": [
    {
      "path": "/full/path/to/project",
      "encodedName": "url-safe-encoded-name"
    }
  ]
}
```

**Response Fields**:
- `projects` (array): Array of project information objects
  - `path` (string): Full file system path to the project directory
  - `encodedName` (string): URL-safe encoded project name for API usage

**Example Usage**:
```bash
curl http://localhost:8080/api/projects
```

### 4. Conversation History

#### GET `/api/projects/:encodedProjectName/histories`

Retrieves list of conversation histories for a specific project.

**URL Parameters**:
- `encodedProjectName` (string): URL-safe encoded project name

**Response**:
```json
{
  "conversations": [
    {
      "sessionId": "session-identifier",
      "startTime": "2024-01-01T10:00:00.000Z",
      "lastTime": "2024-01-01T10:30:00.000Z",
      "messageCount": 15,
      "lastMessagePreview": "Thank you for your help..."
    }
  ]
}
```

**Response Fields**:
- `conversations` (array): Array of conversation summaries
  - `sessionId` (string): Unique session identifier
  - `startTime` (string): ISO timestamp of first message
  - `lastTime` (string): ISO timestamp of last message
  - `messageCount` (number): Total number of messages in conversation
  - `lastMessagePreview` (string): Preview text of the last message

**Example Usage**:
```bash
curl http://localhost:8080/api/projects/my-encoded-project/histories
```

#### GET `/api/projects/:encodedProjectName/histories/:sessionId`

Retrieves detailed conversation history for a specific session.

**URL Parameters**:
- `encodedProjectName` (string): URL-safe encoded project name
- `sessionId` (string): Session identifier

**Response**:
```json
{
  "sessionId": "session-identifier",
  "messages": [
    {
      "timestamp": "2024-01-01T10:00:00.000Z",
      /* Claude SDK message object */
    }
  ],
  "metadata": {
    "startTime": "2024-01-01T10:00:00.000Z",
    "endTime": "2024-01-01T10:30:00.000Z",
    "messageCount": 15
  }
}
```

**Response Fields**:
- `sessionId` (string): Session identifier
- `messages` (array): Array of timestamped Claude SDK messages
- `metadata` (object): Conversation metadata
  - `startTime` (string): ISO timestamp of first message
  - `endTime` (string): ISO timestamp of last message
  - `messageCount` (number): Total number of messages

**Example Usage**:
```bash
curl http://localhost:8080/api/projects/my-encoded-project/histories/session-123
```

## Error Handling

All endpoints return appropriate HTTP status codes and JSON error responses:

**400 Bad Request**:
```json
{
  "error": "Descriptive error message"
}
```

**404 Not Found**:
```json
{
  "error": "Resource not found",
  "details": "Additional error details"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Server error message",
  "details": "Additional error details"
}
```

## Claude SDK Message Types

The streaming chat API returns Claude SDK messages with these common types:

### System Messages
```json
{
  "type": "system",
  "session_id": "session-identifier",
  "cwd": "/working/directory",
  "tools": ["tool1", "tool2"]
}
```

### Assistant Messages
```json
{
  "type": "assistant",
  "session_id": "session-identifier",
  "message": {
    "content": [
      {
        "type": "text",
        "text": "Response text"
      }
    ]
  }
}
```

### Tool Messages
```json
{
  "type": "tool",
  "session_id": "session-identifier",
  "message": {
    "content": [
      {
        "type": "tool_use",
        "name": "tool_name",
        "input": { /* tool parameters */ }
      }
    ]
  }
}
```

### Result Messages
```json
{
  "type": "result",
  "session_id": "session-identifier",
  "subtype": "success",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50
  }
}
```

## Session Management

The API supports conversation continuity through session management:

1. **New Conversation**: Send initial message without `sessionId`
2. **Continue Conversation**: Extract `session_id` from stream responses and include as `sessionId` in subsequent requests
3. **Session Tracking**: The frontend automatically handles session continuity

## Development Notes

- **Debug Mode**: Enable debug logging with `--debug` CLI flag
- **Port Configuration**: Set via PORT environment variable or `--port` CLI argument
- **Claude CLI Dependency**: Requires `claude` command to be available in system PATH
- **Working Directory**: Commands execute in the specified `workingDirectory` or project root
- **Request Tracking**: Use unique `requestId` for each request to enable abort functionality

## Flutter Implementation Guide

### 1. Dependencies

Add these to your `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
  uuid: ^4.1.0
  convert: ^3.1.1
```

### 2. Data Models

```dart
class ChatRequest {
  final String message;
  final String requestId;
  final String? sessionId;
  final List<String>? allowedTools;
  final String? workingDirectory;

  ChatRequest({
    required this.message,
    required this.requestId,
    this.sessionId,
    this.allowedTools,
    this.workingDirectory,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'requestId': requestId,
        if (sessionId != null) 'sessionId': sessionId,
        if (allowedTools != null) 'allowedTools': allowedTools,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
      };
}

class StreamResponse {
  final String type;
  final dynamic data;
  final String? error;

  StreamResponse({required this.type, this.data, this.error});

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    return StreamResponse(
      type: json['type'],
      data: json['data'],
      error: json['error'],
    );
  }
}

class ProjectInfo {
  final String path;
  final String encodedName;

  ProjectInfo({required this.path, required this.encodedName});

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      path: json['path'],
      encodedName: json['encodedName'],
    );
  }
}
```

### 3. API Service

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ClaudeApiService {
  static const String baseUrl = 'http://localhost:8080';
  final Uuid _uuid = const Uuid();

  // Get projects list
  Future<List<ProjectInfo>> getProjects() async {
    final response = await http.get(Uri.parse('$baseUrl/api/projects'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['projects'] as List)
          .map((project) => ProjectInfo.fromJson(project))
          .toList();
    }
    
    throw Exception('Failed to load projects: ${response.statusCode}');
  }

  // Send streaming chat message
  Stream<StreamResponse> sendMessage({
    required String message,
    String? sessionId,
    List<String>? allowedTools,
    String? workingDirectory,
  }) async* {
    final requestId = _uuid.v4();
    
    final request = ChatRequest(
      message: message,
      requestId: requestId,
      sessionId: sessionId,
      allowedTools: allowedTools,
      workingDirectory: workingDirectory,
    );

    final response = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send message: ${response.statusCode}');
    }

    // Process streaming response
    await for (String line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) {
        try {
          final jsonData = jsonDecode(line);
          yield StreamResponse.fromJson(jsonData);
        } catch (e) {
          print('Failed to parse line: $line, error: $e');
        }
      }
    }
  }

  // Abort request
  Future<void> abortRequest(String requestId) async {
    await http.post(Uri.parse('$baseUrl/api/abort/$requestId'));
  }

  // Get conversation histories
  Future<List<ConversationSummary>> getHistories(String encodedProjectName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/projects/$encodedProjectName/histories')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['conversations'] as List)
          .map((conv) => ConversationSummary.fromJson(conv))
          .toList();
    }
    
    throw Exception('Failed to load histories: ${response.statusCode}');
  }
}
```

### 4. Usage Example

```dart
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ClaudeApiService _apiService = ClaudeApiService();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentSessionId;
  StreamSubscription? _streamSubscription;

  void _sendMessage(String message) {
    setState(() {
      _messages.add({
        'type': 'user',
        'content': message,
        'timestamp': DateTime.now(),
      });
    });

    _streamSubscription = _apiService.sendMessage(
      message: message,
      sessionId: _currentSessionId,
      workingDirectory: '/path/to/project',
    ).listen(
      (streamResponse) {
        if (streamResponse.type == 'claude_json') {
          _handleClaudeMessage(streamResponse.data);
        } else if (streamResponse.type == 'error') {
          _handleError(streamResponse.error);
        } else if (streamResponse.type == 'done') {
          _handleStreamComplete();
        }
      },
      onError: (error) {
        print('Stream error: $error');
      },
    );
  }

  void _handleClaudeMessage(dynamic data) {
    // Extract session_id if available
    if (data['session_id'] != null && _currentSessionId == null) {
      _currentSessionId = data['session_id'];
    }

    // Process different message types
    if (data['type'] == 'assistant') {
      setState(() {
        _messages.add({
          'type': 'assistant',
          'content': _extractTextContent(data),
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  String _extractTextContent(dynamic assistantData) {
    if (assistantData['message']?['content'] is List) {
      final content = assistantData['message']['content'] as List;
      return content
          .where((item) => item['type'] == 'text')
          .map((item) => item['text'] ?? '')
          .join('');
    }
    return '';
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
```

### 5. Key Flutter Considerations

1. **Error Handling**: Always wrap API calls in try-catch blocks
2. **Stream Management**: Remember to cancel stream subscriptions in dispose()
3. **State Management**: Use Provider, Riverpod, or BLoC for complex state
4. **Connection Management**: Handle network timeouts and connection errors
5. **Background Processing**: Consider using compute() for heavy JSON parsing
6. **UI Updates**: Use StreamBuilder or setState() to update UI with streaming data
```