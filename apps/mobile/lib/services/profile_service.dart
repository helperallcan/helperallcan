import '../core/supabase_client.dart';
import '../models/helper_profile.dart';
import '../models/profile.dart';

class HelperDashboardData {
  const HelperDashboardData({
    required this.profile,
    required this.workItems,
  });

  final HelperProfile? profile;
  final List<HelperWorkItem> workItems;
}

class ProfileService {
  Future<UserProfile?> currentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    return ensureCurrentProfile();
  }

  Future<UserProfile> ensureCurrentProfile({String? displayName}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row != null) return UserProfile.fromMap(Map<String, dynamic>.from(row));

    final metadataName = user.userMetadata?['display_name'];
    final fallbackName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : metadataName is String && metadataName.trim().isNotEmpty
            ? metadataName.trim()
            : user.email?.split('@').first ?? '新用户';

    final inserted = await supabase
        .from('profiles')
        .insert({
          'id': user.id,
          'display_name': fallbackName,
          'role': AppRole.user.value,
        })
        .select()
        .single();

    return UserProfile.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateProfile({
    required String displayName,
    String? phone,
    String? city,
    String? district,
    String? bio,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('profiles').update({
      'display_name': displayName.trim(),
      'phone': _blankToNull(phone),
      'city': _blankToNull(city),
      'district': _blankToNull(district),
      'bio': _blankToNull(bio),
    }).eq('id', user.id);
  }

  Future<void> setRole(AppRole role) async {
    if (role == AppRole.admin) {
      throw ArgumentError('Admin role cannot be selected from the app.');
    }

    final user = supabase.auth.currentUser!;
    await supabase
        .from('profiles')
        .update({'role': role.value}).eq('id', user.id);
  }

  Future<UserProfile> saveProfile({
    required String displayName,
    required AppRole role,
    String? phone,
    String? city,
    String? district,
    String? bio,
  }) async {
    await updateProfile(
      displayName: displayName,
      phone: phone,
      city: city,
      district: district,
      bio: bio,
    );
    await setRole(role);
    return ensureCurrentProfile();
  }

  Future<Map<String, dynamic>?> helperProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final row = await supabase
        .from('helper_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<HelperDashboardData> helperDashboard() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const HelperDashboardData(profile: null, workItems: []);
    }

    final profileRow = await supabase
        .from('helper_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    final offerRows = await supabase
        .from('task_offers')
        .select(
          'id, task_id, amount, status, created_at, tasks:task_id(id, creator_id, assigned_helper_id, task_type, title, description, location_text, city, district, budget_min, budget_max, is_urgent, status, completion_note, completion_proof_url, completed_at, created_at, categories:category_id(name), subcategories:subcategory_id(name))',
        )
        .eq('helper_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);

    return HelperDashboardData(
      profile: profileRow == null
          ? null
          : HelperProfile.fromMap(Map<String, dynamic>.from(profileRow)),
      workItems: (offerRows as List<dynamic>)
          .map((row) =>
              HelperWorkItem.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }

  Future<void> saveHelperProfile({
    required String headline,
    required String bio,
    required List<String> skills,
    required List<String> serviceAreas,
    double? hourlyRate,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('helper_profiles').upsert({
      'user_id': user.id,
      'headline': headline.trim(),
      'bio': bio.trim(),
      'skills': skills,
      'service_areas': serviceAreas,
      'hourly_rate': hourlyRate,
      'is_available': true,
    }, onConflict: 'user_id');

    await setRole(AppRole.helper);
  }

  Future<void> requestHelperVerification() async {
    await supabase.rpc('request_helper_verification');
  }

  String? _blankToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
