import 'package:flutter_test/flutter_test.dart';
import 'package:zhao_bang_shou/models/helper_profile.dart';
import 'package:zhao_bang_shou/models/offer.dart';
import 'package:zhao_bang_shou/models/task.dart';

void main() {
  group('HelperVerificationStatus.fromValue', () {
    test('parses known statuses and falls back to none', () {
      expect(
        HelperVerificationStatus.fromValue('pending'),
        HelperVerificationStatus.pending,
      );
      expect(
        HelperVerificationStatus.fromValue('approved'),
        HelperVerificationStatus.approved,
      );
      expect(
        HelperVerificationStatus.fromValue('unknown'),
        HelperVerificationStatus.none,
      );
    });

    test('allows requesting verification only from none or rejected', () {
      expect(HelperVerificationStatus.none.canRequest, isTrue);
      expect(HelperVerificationStatus.rejected.canRequest, isTrue);
      expect(HelperVerificationStatus.pending.canRequest, isFalse);
      expect(HelperVerificationStatus.approved.canRequest, isFalse);
    });
  });

  test('HelperProfile.fromMap maps stats and tags safely', () {
    final profile = HelperProfile.fromMap({
      'id': 'helper-profile-id',
      'user_id': 'helper-id',
      'headline': 'Fast local helper',
      'bio': 'I help with errands and moving.',
      'skills': ['moving', 'errands'],
      'service_areas': ['Cheras', 'PJ'],
      'hourly_rate': 35,
      'verification_status': 'approved',
      'verification_note': 'Verified',
      'completed_tasks': 8,
      'rating_average': 4.75,
      'rating_count': 6,
      'is_available': true,
    });

    expect(profile.skills, ['moving', 'errands']);
    expect(profile.serviceAreas, ['Cheras', 'PJ']);
    expect(profile.hourlyRate, 35);
    expect(profile.verificationStatus, HelperVerificationStatus.approved);
    expect(profile.ratingLabel, '4.8 / 5');
  });

  test('HelperWorkItem.fromMap maps nested task and offer state', () {
    final item = HelperWorkItem.fromMap({
      'id': 'offer-id',
      'task_id': 'task-id',
      'amount': 80,
      'status': 'accepted',
      'created_at': '2026-05-26T06:00:00.000Z',
      'tasks': {
        'id': 'task-id',
        'creator_id': 'owner-id',
        'assigned_helper_id': 'helper-id',
        'task_type': 'help',
        'title': 'Move boxes',
        'description': 'Move boxes upstairs.',
        'location_text': 'Cheras',
        'is_urgent': true,
        'status': 'in_progress',
        'created_at': '2026-05-26T05:30:00.000Z',
      },
    });

    expect(item.offerStatus, OfferStatus.accepted);
    expect(item.task.status, TaskStatus.inProgress);
    expect(item.task.title, 'Move boxes');
    expect(item.task.isUrgent, isTrue);
  });
}
