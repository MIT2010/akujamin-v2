/// Counseling chat with a psychologist — migrated from the old app's
/// `counseling` feature (session list + realtime chat thread). See
/// MIGRATION_LOG.md's `counseling` row and permanent findings #1/#3/#6.
library;

export 'src/data/datasources/chat_remote_datasource.dart';
export 'src/data/datasources/counseling_remote_datasource.dart';
export 'src/data/models/chat_message_model.dart';
export 'src/data/models/counseling_session_model.dart';
export 'src/data/repositories/chat_repository_impl.dart';
export 'src/data/repositories/counseling_repository_impl.dart';
export 'src/domain/entities/chat_message.dart';
export 'src/domain/entities/counseling_session.dart';
export 'src/domain/repositories/chat_repository.dart';
export 'src/domain/repositories/counseling_repository.dart';
export 'src/presentation/cubit/chat_cubit.dart';
export 'src/presentation/cubit/chat_state.dart';
export 'src/presentation/cubit/counseling_cubit.dart';
export 'src/presentation/cubit/counseling_state.dart';
export 'src/presentation/pages/chat_page.dart';
export 'src/presentation/pages/counseling_list_page.dart';
export 'src/realtime/counseling_socket_gateway.dart';
export 'src/realtime/reconnect_backoff.dart';
export 'src/realtime/socket_event.dart';
