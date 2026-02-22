part of 'app_bloc.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class AppInitialized extends AppEvent {
  const AppInitialized();
}

class AppResumed extends AppEvent {
  const AppResumed();
}

class AppPaused extends AppEvent {
  const AppPaused();
}

class SyncRequested extends AppEvent {
  const SyncRequested();
}

class BatteryLevelChanged extends AppEvent {
  final int level;
  const BatteryLevelChanged(this.level);

  @override
  List<Object?> get props => [level];
}

class OnboardingCompleted extends AppEvent {
  const OnboardingCompleted();
}
