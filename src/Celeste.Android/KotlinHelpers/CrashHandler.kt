/**
 * CrashHandler.kt - Tratador de crashes para Celeste Android
 * 
 * Este é um auxiliar opcional Kotlin que captura exceções não tratadas
 * e registra em um arquivo de log para análise pós-crash.
 * 
 * Se causar instabilidade, pode ser desabilitado sem quebrar o app.
 */

package Celestegame.app

import android.app.Application
import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Handler de exceções globais
 */
class CrashHandler(private val context: Context) : Thread.UncaughtExceptionHandler {
    
    private var defaultHandler: Thread.UncaughtExceptionHandler? = null
    
    init {
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler(this)
    }
    
    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        try {
            // Log para arquivo
            logCrash(thread, throwable)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // Chamar handler padrão do Android
        defaultHandler?.uncaughtException(thread, throwable)
    }
    
    private fun logCrash(thread: Thread, throwable: Throwable) {
        try {
            val logDir = context.getExternalFilesDir(null) ?: context.filesDir
            val crashLogsDir = File(logDir, "CrashLogs")
            crashLogsDir.mkdirs()
            
            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
            val crashFile = File(crashLogsDir, "crash_$timestamp.txt")
            
            val sb = StringBuilder()
            sb.append("=== CRASH LOG ===\n")
            sb.append("Timestamp: ${Date()}\n")
            sb.append("Thread: ${thread.name} (ID: ${thread.id})\n")
            sb.append("Exception: ${throwable.javaClass.name}\n")
            sb.append("Message: ${throwable.message}\n")
            sb.append("\nStackTrace:\n")
            
            for (element in throwable.stackTrace) {
                sb.append("  at $element\n")
            }
            
            // Adicionar causa se existir
            var cause = throwable.cause
            while (cause != null) {
                sb.append("\nCaused by: ${cause.javaClass.name}: ${cause.message}\n")
                for (element in cause.stackTrace) {
                    sb.append("  at $element\n")
                }
                cause = cause.cause
            }
            
            crashFile.writeText(sb.toString())
            
            // Also print to logcat
            android.util.Log.e("CELESTE_CRASH", sb.toString())
            
        } catch (e: Exception) {
            android.util.Log.e("CRASH_HANDLER", "Failed to log crash", e)
        }
    }
}

/**
 * Application class para inicializar crash handler
 */
class CelesteApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        try {
            // Inicializar crash handler
            CrashHandler(this)
            android.util.Log.i("CELESTE", "CrashHandler initialized")
        } catch (e: Exception) {
            android.util.Log.e("CELESTE", "Failed to initialize CrashHandler", e)
            // Não bloquear app se crash handler falhar
        }
    }
}
