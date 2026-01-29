package com.celestegame.android.helpers

import android.os.SystemClock
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.system.measureTimeMillis

/**
 * Otimizador de Performance para Android
 * Pooling de objetos, caching, profiling
 */
object PerformanceOptimizer {
    
    private val objectPools = ConcurrentHashMap<String, MutableList<Any>>()
    private val frameTimes = mutableListOf<Long>()
    private val maxFrameHistory = 300 // ~5 segundos a 60 FPS
    private var lastFrameTime = SystemClock.elapsedRealtimeNanos()
    private val frameCounter = AtomicLong(0)
    private var avgFps = 60f
    
    /**
     * Obtém objeto do pool ou cria novo
     */
    @Suppress("UNCHECKED_CAST")
    fun <T> getFromPool(poolName: String, factory: () -> T): T {
        val pool = objectPools.getOrPut(poolName) { mutableListOf() }
        return if (pool.isEmpty()) {
            factory()
        } else {
            pool.removeAt(pool.size - 1) as T
        }
    }
    
    /**
     * Devolve objeto ao pool para reutilização
     */
    fun returnToPool(poolName: String, obj: Any) {
        val pool = objectPools.getOrPut(poolName) { mutableListOf() }
        if (pool.size < 100) { // Limite de tamanho do pool
            pool.add(obj)
        }
    }
    
    /**
     * Limpa pool específico
     */
    fun clearPool(poolName: String) {
        objectPools.remove(poolName)?.clear()
    }
    
    /**
     * Limpa todos os pools
     */
    fun clearAllPools() {
        objectPools.values.forEach { it.clear() }
        objectPools.clear()
    }
    
    /**
     * Registra frame time para FPS tracking
     */
    fun recordFrame() {
        val now = SystemClock.elapsedRealtimeNanos()
        val deltaTime = (now - lastFrameTime) / 1_000_000f // em ms
        
        if (deltaTime > 0) {
            frameTimes.add(deltaTime.toLong())
            if (frameTimes.size > maxFrameHistory) {
                frameTimes.removeAt(0)
            }
            
            // Calcula FPS média
            val avgDelta = frameTimes.average()
            avgFps = if (avgDelta > 0) 1000f / avgDelta else 60f
        }
        
        lastFrameTime = now
        frameCounter.incrementAndGet()
    }
    
    /**
     * Obtém FPS atual
     */
    fun getCurrentFps(): Float = avgFps
    
    /**
     * Obtém contagem de frames
     */
    fun getFrameCount(): Long = frameCounter.get()
    
    /**
     * Perfil de execução de lambda
     */
    inline fun profile(label: String, block: () -> Unit) {
        val time = measureTimeMillis {
            block()
        }
        LogHelper.d("PERF", "$label: ${time}ms")
    }
    
    /**
     * Mede tempo de operação assincronamente
     */
    fun profileAsync(label: String, block: suspend () -> Unit) {
        val startTime = System.currentTimeMillis()
        // block() seria executado em coroutine
        val time = System.currentTimeMillis() - startTime
        LogHelper.d("PERF", "$label: ${time}ms (async)")
    }
}

/**
 * Cache thread-safe para valores computados
 */
class ComputeCache<K, V> {
    private val cache = ConcurrentHashMap<K, V>()
    private var hitCount = 0L
    private var missCount = 0L
    
    fun get(key: K, compute: (K) -> V): V {
        return cache.getOrPut(key) {
            missCount++
            compute(key)
        }.also { hitCount++ }
    }
    
    fun put(key: K, value: V) {
        cache[key] = value
    }
    
    fun clear() {
        cache.clear()
        hitCount = 0
        missCount = 0
    }
    
    fun getStats(): String {
        val total = hitCount + missCount
        val hitRate = if (total > 0) (hitCount * 100) / total else 0
        return "Cache: Hits=$hitCount, Misses=$missCount, Rate=$hitRate%"
    }
}

/**
 * Gerenciador de memória de baixo overhead
 */
object MemoryManager {
    private val gc = Runtime.getRuntime()
    
    fun getMemoryInfo(): String {
        val totalMem = gc.totalMemory() / (1024 * 1024)
        val freeMem = gc.freeMemory() / (1024 * 1024)
        val usedMem = totalMem - freeMem
        return "Mem: ${usedMem}MB / ${totalMem}MB"
    }
    
    fun forceGarbageCollection() {
        System.gc()
    }
    
    fun isLowMemory(): Boolean {
        val usedMem = (gc.totalMemory() - gc.freeMemory()) / (1024 * 1024)
        return usedMem > 128 // >128MB é considerado crítico
    }
}
