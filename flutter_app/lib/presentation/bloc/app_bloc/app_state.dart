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
  final String userId;
  const AppReady({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class AppError extends AppState {
  final String message;
  const AppError({required this.message});

  @override
  List<Object?> get props => [message];
}
