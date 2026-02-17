part of 'app_bloc.dart';

abstract class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

class AppInitializing extends AppState {
  const AppInitializing();
}

class AppOnboardingRequired extends AppState {
  const AppOnboardingRequired();
}

class AppReady extends AppState {
  const AppReady();
}

class AppError extends AppState {
  final String message;
  const AppError({required this.message});

  @override
  List<Object?> get props => [message];
}
