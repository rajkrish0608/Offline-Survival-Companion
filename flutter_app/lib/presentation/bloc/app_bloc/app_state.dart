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
  final bool isSurvivalMode;
  const AppReady({required this.userId, this.isSurvivalMode = false});

  @override
  List<Object?> get props => [userId, isSurvivalMode];

  AppReady copyWith({String? userId, bool? isSurvivalMode}) {
    return AppReady(
      userId: userId ?? this.userId,
      isSurvivalMode: isSurvivalMode ?? this.isSurvivalMode,
    );
  }
}

class AppError extends AppState {
  final String message;
  const AppError({required this.message});

  @override
  List<Object?> get props => [message];
}
