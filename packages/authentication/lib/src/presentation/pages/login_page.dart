import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

/// §23 — a `StatefulWidget` (not `StatelessWidget`) so the text controllers
/// have a home to live in and get disposed; the doc's illustrative
/// snippet referenced them without declaring them.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginCubit>(),
      child: const LoginView(),
    );
  }
}

/// Split from [LoginPage] (and left un-exported from the package barrel)
/// so widget tests can drive it directly with a fake `LoginCubit` via
/// `BlocProvider.value`, without going through `get_it`.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => LoginViewState();
}

class LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            switch (state) {
              case LoginSuccess():
                context.go('/home');
              case LoginFailureState(:final failure):
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(failure.message)));
              case LoginInitial() || LoginLoading():
                break;
            }
          },
          builder: (context, state) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTextField(label: 'Email', controller: _emailController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Password',
                obscure: true,
                controller: _passwordController,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Login',
                loading: state is LoginLoading,
                onPressed: () => context.read<LoginCubit>().submit(
                  email: _emailController.text,
                  password: _passwordController.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
