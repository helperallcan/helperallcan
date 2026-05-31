import 'package:flutter_test/flutter_test.dart';
import 'package:helper/models/message.dart';
import 'package:helper/models/offer.dart';
import 'package:helper/models/review.dart';
import 'package:helper/models/task.dart';

void main() {
  test('Task.fromMap maps lifecycle completion fields', () {
    final task = Task.fromMap({
      'id': 'task-id',
      'creator_id': 'owner-id',
      'assigned_helper_id': 'helper-id',
      'task_type': 'help',
      'title': 'Move boxes',
      'description': 'Move boxes to the second floor.',
      'location_text': 'Cheras',
      'is_urgent': false,
      'status': 'completed',
      'completion_note': 'All boxes moved.',
      'completion_proof_url': 'helper-id/task-id/proof.jpg',
      'completed_at': '2026-05-25T10:15:00.000Z',
      'cancelled_at': null,
      'expires_at': '2026-06-25T09:00:00.000Z',
      'created_at': '2026-05-25T09:00:00.000Z',
    });

    expect(task.status, TaskStatus.completed);
    expect(task.assignedHelperId, 'helper-id');
    expect(task.completionNote, 'All boxes moved.');
    expect(task.completionProofUrl, 'helper-id/task-id/proof.jpg');
    expect(task.completedAt, isNotNull);
    expect(task.expiresAt, isNotNull);
    expect(task.status.isClosed, isTrue);
  });

  test('TaskStatus exposes lifecycle action rules', () {
    expect(TaskStatus.open.canReceiveOffers, isTrue);
    expect(TaskStatus.offered.canReceiveOffers, isTrue);
    expect(TaskStatus.assigned.canOwnerReopen, isTrue);
    expect(TaskStatus.inProgress.canConfirmCompletion, isTrue);
    expect(TaskStatus.completed.canOwnerCancel, isFalse);
    expect(TaskStatus.cancelled.isClosed, isTrue);
  });

  test('TaskOffer.fromMap maps helper profile display name', () {
    final offer = TaskOffer.fromMap({
      'id': 'offer-id',
      'task_id': 'task-id',
      'helper_id': 'helper-id',
      'amount': 80,
      'message': 'I can do it today.',
      'estimated_minutes': 45,
      'status': 'accepted',
      'created_at': '2026-05-25T09:30:00.000Z',
      'helper': {'display_name': 'Ah Ming'},
    });

    expect(offer.status, OfferStatus.accepted);
    expect(offer.status.canWithdraw, isFalse);
    expect(offer.amount, 80);
    expect(offer.estimatedMinutes, 45);
    expect(offer.helperName, 'Ah Ming');
  });

  test('OfferStatus only allows pending offers to be withdrawn', () {
    expect(OfferStatus.pending.canWithdraw, isTrue);
    expect(OfferStatus.accepted.canWithdraw, isFalse);
    expect(OfferStatus.rejected.canWithdraw, isFalse);
    expect(OfferStatus.withdrawn.canWithdraw, isFalse);
  });

  test('ChatMessage.fromMap falls back to empty body safely', () {
    final message = ChatMessage.fromMap({
      'id': 'message-id',
      'conversation_id': 'conversation-id',
      'sender_id': 'sender-id',
      'created_at': '2026-05-25T09:45:00.000Z',
    });

    expect(message.body, '');
    expect(message.conversationId, 'conversation-id');
  });

  test('TaskReview.fromMap maps reviewer and reviewee display names', () {
    final review = TaskReview.fromMap({
      'id': 'review-id',
      'task_id': 'task-id',
      'reviewer_id': 'owner-id',
      'reviewee_id': 'helper-id',
      'rating': 5,
      'comment': 'Great work.',
      'created_at': '2026-05-25T11:00:00.000Z',
      'reviewer': {'display_name': 'Owner'},
      'reviewee': {'display_name': 'Helper'},
    });

    expect(review.rating, 5);
    expect(review.comment, 'Great work.');
    expect(review.reviewerName, 'Owner');
    expect(review.revieweeName, 'Helper');
  });
}
