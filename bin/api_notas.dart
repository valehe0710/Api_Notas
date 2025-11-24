import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:path/path.dart' as path;

void main() async {
  final router = Router();

  // leer/escribir archivos JSON
  Future<Map<String, dynamic>> _readJson(String fileName) async {
    final file = File(path.join(Directory.current.path, fileName));
    if (await file.exists()) {
      return jsonDecode(await file.readAsString());
    }
    return {};
  }

  Future<void> _writeJson(String fileName, Map<String, dynamic> data) async {
    final file = File(path.join(Directory.current.path, fileName));
    await file.writeAsString(jsonEncode(data));
  }

  router.get('/', (Request request) {
    return Response.ok('Bienvenido a la API de Notas');
  });

  router.get('/user/<email>', (Request request, String email) async {
    final users = await _readJson('users.json');

    if (users.containsKey(email)) {
      return Response.ok(jsonEncode(users[email]));
    }

    return Response(404,
        body: jsonEncode({'error': 'Usuario no encontrado'}));
  });

  router.post('/register', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final users = await _readJson('users.json');
    final email = data['email'];

    if (users.containsKey(email)) {
      return Response(400,
          body: jsonEncode({'error': 'Usuario ya existe'}));
    }

    users[email] = {
      'name': data['name'],
      'email': email,
      'password': data['password'],
      'photoPath': data['photoPath'] ?? '',
    };

    await _writeJson('users.json', users);

    return Response.ok(jsonEncode({'message': 'Usuario registrado'}));
  });

  router.post('/login', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final users = await _readJson('users.json');
    final email = data['email'];

    if (users.containsKey(email) &&
        users[email]['password'] == data['password']) {
      return Response.ok(jsonEncode(users[email]));
    }

    return Response(401,
        body: jsonEncode({'error': 'Credenciales incorrectas'}));
  });

  //actualizar usuario
  router.put('/user/<oldEmail>', (Request request, String oldEmail) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final users = await _readJson('users.json');
    final newEmail = data['email'];

    if (users.containsKey(oldEmail)) {
      users.remove(oldEmail);
      users[newEmail] = {
        'name': data['name'],
        'email': newEmail,
        'password': data['password'],
        'photoPath': data['photoPath'],
      };
      await _writeJson('users.json', users);
      return Response.ok(jsonEncode({'message': 'Usuario actualizado'}));
    }

    return Response(404, body: jsonEncode({'error': 'Usuario no encontrado'}));
  });

  //eliminar usuario
  router.delete('/user/<email>', (Request request, String email) async {
    final users = await _readJson('users.json');
    final history = await _readJson('history.json');  // Leer historial

    if (users.containsKey(email)) {
      users.remove(email);
      await _writeJson('users.json', users);

      //eliminar historial del usuario
      if (history.containsKey(email)) {
        history.remove(email);
        await _writeJson('history.json', history);
      }

      return Response.ok(jsonEncode({'message': 'Usuario y historial eliminados'}));
    }

    return Response(404, body: jsonEncode({'error': 'Usuario no encontrado'}));
  });

  router.post('/notes', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final notes = await _readJson('notes.json');

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    notes[id] = {
      'id': id,
      'title': data['title'],
      'content': data['content'],
      'date': data['date'],
      'userId': data['userId'], 
    };

    await _writeJson('notes.json', notes);

    return Response.ok(jsonEncode({'message': 'Nota guardada'}));
  });

  router.get('/notes/<userId>', (Request request, String userId) async {
    final notes = await _readJson('notes.json');
    final userNotes = notes.values.where((note) => note['userId'] == userId).toList();
    return Response.ok(jsonEncode(userNotes));
  });

  //actualizar nota
  router.put('/notes/<id>', (Request request, String id) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final notes = await _readJson('notes.json');

    if (notes.containsKey(id)) {
      notes[id] = {
        'id': id,
        'title': data['title'],
        'content': data['content'],
        'date': notes[id]['date'], //mantener fecha original
        'userId': notes[id]['userId'], //y userId
      };
      await _writeJson('notes.json', notes);
      return Response.ok(jsonEncode({'message': 'Nota actualizada'}));
    }

    return Response(404, body: jsonEncode({'error': 'Nota no encontrada'}));
  });

  //eliminar nota
  router.delete('/notes/<id>', (Request request, String id) async {
    final notes = await _readJson('notes.json');

    if (notes.containsKey(id)) {
      notes.remove(id);
      await _writeJson('notes.json', notes);
      return Response.ok(jsonEncode({'message': 'Nota eliminada'}));
    }

    return Response(404, body: jsonEncode({'error': 'Nota no encontrada'}));
  });

  router.post('/photos', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final photos = await _readJson('photos.json');

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    photos[id] = {
      'id': id,
      'path': data['path'],
      'userId': data['userId'], 
    };

    await _writeJson('photos.json', photos);

    return Response.ok(jsonEncode({'message': 'Foto guardada'}));
  });

  router.get('/photos/<userId>', (Request request, String userId) async {
    final photos = await _readJson('photos.json');
    final userPhotos = photos.values.where((photo) => photo['userId'] == userId).toList();
    return Response.ok(jsonEncode(userPhotos));
  });

  // eliminar foto
  router.delete('/photos/<id>', (Request request, String id) async {
    final photos = await _readJson('photos.json');

    if (photos.containsKey(id)) {
      photos.remove(id);
      await _writeJson('photos.json', photos);
      return Response.ok(jsonEncode({'message': 'Foto eliminada'}));
    }

    return Response(404, body: jsonEncode({'error': 'Foto no encontrada'}));
  });

  //agregar al historial por usuario
  router.post('/history', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final history = await _readJson('history.json');
    final email = data['email'];

    if (!history.containsKey(email)) {
      history[email] = [];
    }
    history[email].add('${DateTime.now().toIso8601String()}: ${data['action']}');
    await _writeJson('history.json', history);

    return Response.ok(jsonEncode({'message': 'Acción agregada al historial'}));
  });

  //  obtener historial por usuario
  router.get('/history/<email>', (Request request, String email) async {
    final history = await _readJson('history.json');
    final userHistory = history[email] ?? [];
    return Response.ok(jsonEncode(userHistory));
  });

  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await shelf_io.serve(handler, 'localhost', 8080);

  print('Servidor corriendo en http://localhost:8080');
}