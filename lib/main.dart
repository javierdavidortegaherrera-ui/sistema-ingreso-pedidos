import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configuracion.dart';
import 'datos/repositorio.dart';
import 'controladores/controlador_sistema.dart';
import 'vistas/inicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Repositorio? local;
  String? error;
  try {
    if (Configuracion.usarFirebase) {
      await Firebase.initializeApp(options: Configuracion.firebase);
    } else {
      local = RepositorioLocal(await SharedPreferences.getInstance());
    }
  } catch (e) {
    error = e is StateError ? e.message.toString() : mensajeError(e);
  }
  runApp(AplicacionPedidos(local: local, errorInicio: error));
}

class AplicacionPedidos extends StatelessWidget {
  const AplicacionPedidos({super.key, this.local, this.errorInicio});
  final Repositorio? local;
  final String? errorInicio;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ingreso de pedidos',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB71C2C))
          .copyWith(
            primary: const Color(0xFFB71C2C),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFFFE9ED),
            onPrimaryContainer: const Color(0xFF72101C),
          ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
    ),
    home: errorInicio != null
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No se pudo iniciar el sistema.\n\n$errorInicio'),
              ),
            ),
          )
        : local != null
        ? EspacioTrabajo(repositorio: local!, enNube: false)
        : const SesionFirebase(),
  );
}

class SesionFirebase extends StatelessWidget {
  const SesionFirebase({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(child: Text(mensajeError(snapshot.error!))),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final usuario = snapshot.data;
      return usuario == null
          ? const IniciarSesion()
          : EspacioTrabajo(
              key: ValueKey(usuario.uid),
              repositorio: RepositorioFirebase(usuario.uid),
              enNube: true,
            );
    },
  );
}

class IniciarSesion extends StatefulWidget {
  const IniciarSesion({super.key});
  @override
  State<IniciarSesion> createState() => _IniciarSesionState();
}

class _IniciarSesionState extends State<IniciarSesion> {
  final correo = TextEditingController();
  final clave = TextEditingController();
  final formulario = GlobalKey<FormState>();
  bool ocupado = false;
  String? error;
  @override
  void dispose() {
    correo.dispose();
    clave.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (!formulario.currentState!.validate()) {
      return;
    }
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo.text.trim(),
        password: clave.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = mensajeError(e));
      }
    } finally {
      if (mounted) {
        setState(() => ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formulario,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/branding/icono-pedidos-rojo-blanco.png',
                          width: 80,
                          height: 80,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tus pedidos, en orden.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inicia sesión para acceder a tu espacio de trabajo en Firebase.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: correo,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Escribe un correo válido.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: clave,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Escribe tu contraseña.'
                          : null,
                      onFieldSubmitted: (_) {
                        if (!ocupado) {
                          entrar();
                        }
                      },
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: ocupado ? null : entrar,
                      child: Text(ocupado ? 'Ingresando…' : 'Ingresar'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'El administrador crea las cuentas desde Firebase Authentication.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EspacioTrabajo extends StatefulWidget {
  const EspacioTrabajo({
    super.key,
    required this.repositorio,
    required this.enNube,
  });
  final Repositorio repositorio;
  final bool enNube;
  @override
  State<EspacioTrabajo> createState() => _EspacioTrabajoState();
}

class _EspacioTrabajoState extends State<EspacioTrabajo> {
  late final ControladorSistema controlador;
  @override
  void initState() {
    super.initState();
    controlador = ControladorSistema(widget.repositorio, enNube: widget.enNube)
      ..cargar();
  }

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Inicio(controlador: controlador);
}
