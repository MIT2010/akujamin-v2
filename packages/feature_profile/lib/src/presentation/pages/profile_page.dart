import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/profile.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>()..getProfile(),
      child: const ProfileView(),
    );
  }
}

/// Split from [ProfilePage] (and left un-exported from the package barrel)
/// so widget tests can drive it directly with a fake `ProfileCubit` via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// `authentication`'s `LoginView`/`feature_home`'s `HomeView`.
///
/// A `StatefulWidget`, not stateless: the text controllers need a home to
/// live in and get disposed (§23), and need to be re-populated once
/// `getProfile()` resolves — but never re-populated while `saving`, or the
/// user's own in-progress edits would get clobbered mid-submit.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => ProfileViewState();
}

class ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateFrom(Profile profile) {
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _bioController.text = profile.bio;
    _phoneController.text = profile.phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          switch (state) {
            case ProfileLoaded(:final profile):
              _populateFrom(profile);
            case ProfileInitial() ||
                ProfileLoading() ||
                ProfileSaving() ||
                ProfileError():
              break;
          }
        },
        builder: (context, state) => switch (state) {
          ProfileInitial() ||
          ProfileLoading() => const Center(child: CircularProgressIndicator()),
          ProfileError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () => context.read<ProfileCubit>().getProfile(),
                  ),
                ],
              ),
            ),
          ),
          ProfileLoaded() || ProfileSaving() => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                AppTextField(label: 'Name', controller: _nameController),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Bio', controller: _bioController),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Save',
                  loading: state is ProfileSaving,
                  onPressed: () => context.read<ProfileCubit>().updateProfile(
                    Profile(
                      name: _nameController.text,
                      email: _emailController.text,
                      bio: _bioController.text,
                      phoneNumber: _phoneController.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
