import 'dart:math';
import 'package:get/get.dart';
import '../../memory/hive_service.dart';

/// Represents a vector document stored in Kairo's semantic memory.
class SemanticDocument {
  final String id;
  final String text;
  final List<double> vector;
  final Map<String, dynamic> metadata;

  const SemanticDocument({
    required this.id,
    required this.text,
    required this.vector,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'vector': vector,
      'metadata': metadata,
    };
  }

  factory SemanticDocument.fromMap(Map<String, dynamic> map) {
    return SemanticDocument(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      vector: (map['vector'] as List? ?? []).map((e) => (e as num).toDouble()).toList(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

/// Local Vector Search & Embeddings Engine utilizing TF-IDF.
class SemanticMemory {
  final Map<String, double> _idf = {};
  final List<SemanticDocument> _documents = [];

  /// Add a document to semantic memory, building local term vectors.
  void addDocument(String id, String text, Map<String, dynamic> metadata) {
    final terms = _tokenize(text);
    if (terms.isEmpty) return;

    // Calculate term frequencies (TF)
    final Map<String, double> tf = {};
    for (final term in terms) {
      tf[term] = (tf[term] ?? 0.0) + 1.0;
    }
    tf.forEach((k, v) => tf[k] = v / terms.length);

    // Build term space from existing document vectors
    final allTerms = _idf.keys.toSet()..addAll(tf.keys);
    
    // Update Document Frequency (DF) & Inverse Document Frequency (IDF)
    _idf.clear();
    final totalDocs = _documents.length + 1;
    final Map<String, int> df = {};

    for (final doc in _documents) {
      final docTerms = _tokenize(doc.text).toSet();
      for (final t in docTerms) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    for (final t in tf.keys) {
      df[t] = (df[t] ?? 0) + 1;
    }

    df.forEach((term, count) {
      _idf[term] = log(totalDocs / count) + 1.0;
    });

    // Construct TF-IDF vector for this document
    final vector = <double>[];
    for (final term in allTerms) {
      final termTf = tf[term] ?? 0.0;
      final termIdf = _idf[term] ?? 1.0;
      vector.add(termTf * termIdf);
    }

    // Standardize previous document vectors to new term space dimension
    for (int i = 0; i < _documents.length; i++) {
      final doc = _documents[i];
      final docTf = _calculateTf(doc.text);
      final newVec = <double>[];
      for (final term in allTerms) {
        final termTf = docTf[term] ?? 0.0;
        final termIdf = _idf[term] ?? 1.0;
        newVec.add(termTf * termIdf);
      }
      _documents[i] = SemanticDocument(
        id: doc.id,
        text: doc.text,
        vector: newVec,
        metadata: doc.metadata,
      );
    }

    _documents.add(
      SemanticDocument(
        id: id,
        text: text,
        vector: vector,
        metadata: metadata,
      ),
    );
  }

  /// Query semantic memory using Cosine Similarity.
  List<Map<String, dynamic>> query(String queryText, {int limit = 3}) {
    final queryTf = _calculateTf(queryText);
    final queryVec = <double>[];
    final allTerms = _idf.keys.toList();

    for (final term in allTerms) {
      final termTf = queryTf[term] ?? 0.0;
      final termIdf = _idf[term] ?? 1.0;
      queryVec.add(termTf * termIdf);
    }

    final List<Map<String, dynamic>> results = [];
    for (final doc in _documents) {
      final similarity = _calculateCosineSimilarity(queryVec, doc.vector);
      results.add({
        'document': doc,
        'similarity': similarity,
      });
    }

    results.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));
    return results.take(limit).toList();
  }

  Map<String, double> _calculateTf(String text) {
    final terms = _tokenize(text);
    final Map<String, double> tf = {};
    for (final term in terms) {
      tf[term] = (tf[term] ?? 0.0) + 1.0;
    }
    tf.forEach((k, v) => tf[k] = v / max(1, terms.length));
    return tf;
  }

  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length || vec1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      normA += vec1[i] * vec1[i];
      normB += vec2[i] * vec2[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t.length > 2)
        .toList();
  }
}

/// Manages Kairo's Short-Term (in-memory) and Long-Term (Hive stored) Memory.
class KairoMemory extends GetxService {
  final HiveService _hive = Get.find<HiveService>();
  final SemanticMemory _semanticMemory = SemanticMemory();

  // Short-Term Memory FIFO Buffers
  final List<String> actionHistory = [];
  final List<String> screenHistory = [];
  final List<String> taskHistory = [];

  static const int _maxShortTermItems = 15;

  /// Logs a short-term action.
  void recordAction(String action) {
    actionHistory.add(action);
    if (actionHistory.length > _maxShortTermItems) {
      actionHistory.removeAt(0);
    }
  }

  /// Logs a short-term screen signature.
  void recordScreen(String screenSignature) {
    screenHistory.add(screenSignature);
    if (screenHistory.length > _maxShortTermItems) {
      screenHistory.removeAt(0);
    }
  }

  /// Save long-term episodic task memory and index it in the semantic memory database.
  Future<void> saveEpisodicMemory(String goal, Map<String, dynamic> resultDetails) async {
    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Write document to Hive for persistent storage
    final Map<String, dynamic> docData = {
      'goal': goal,
      'result': resultDetails,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _hive.saveTask(docId, docData);

    // Index terms in local vector search engine
    _semanticMemory.addDocument(docId, goal, docData);
  }

  /// Retrieve the top matching persistent task memories for semantic retrieval.
  List<Map<String, dynamic>> searchMemories(String queryGoal, {int limit = 3}) {
    return _semanticMemory.query(queryGoal, limit: limit);
  }
}
