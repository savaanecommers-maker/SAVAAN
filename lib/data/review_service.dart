import 'api_client.dart';
import '../models/review_model.dart';

class ReviewService {
  Future<List<ReviewModel>> getReviews(String productId) async {
    final res = await ApiClient.get('/api/reviews?product_id=$productId', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> addReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
  }) async {
    final res = await ApiClient.post('/api/reviews', {
      'product_id': productId,
      'rating': rating,
      if (title != null) 'title': title,
      if (body  != null) 'body':  body,
    });
    return res.isSuccess ? null : res.error;
  }

  Future<String?> deleteReview(String reviewId) async {
    final res = await ApiClient.delete('/api/reviews/$reviewId');
    return res.isSuccess ? null : res.error;
  }
}
