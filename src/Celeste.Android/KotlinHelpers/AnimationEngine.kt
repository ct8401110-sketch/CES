package com.celestegame.android.helpers

import android.view.animation.DecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.view.animation.LinearInterpolator
import kotlin.math.sin
import kotlin.math.cos
import kotlin.math.PI

/**
 * Sistema de Animações Fluidas com Easing Functions
 * Zero GC allocation, pooling integrado
 */
object AnimationEngine {
    
    private val animationPool = mutableListOf<Animation>()
    private val activeAnimations = mutableListOf<Animation>()
    private var lastUpdateTime = System.currentTimeMillis()
    
    /**
     * Tipos de easing
     */
    enum class EasingType {
        LINEAR,
        EASE_IN, EASE_OUT, EASE_IN_OUT,
        EASE_IN_QUAD, EASE_OUT_QUAD,
        EASE_IN_CUBIC, EASE_OUT_CUBIC,
        EASE_IN_BACK, EASE_OUT_BACK,
        EASE_IN_ELASTIC, EASE_OUT_ELASTIC,
        EASE_IN_BOUNCE, EASE_OUT_BOUNCE
    }
    
    /**
     * Calcula valor easing
     */
    fun easeValue(t: Float, type: EasingType): Float {
        val tClamped = t.coerceIn(0f, 1f)
        
        return when (type) {
            EasingType.LINEAR -> tClamped
            
            EasingType.EASE_IN -> tClamped * tClamped
            EasingType.EASE_OUT -> tClamped * (2 - tClamped)
            EasingType.EASE_IN_OUT -> if (tClamped < 0.5) {
                2 * tClamped * tClamped
            } else {
                -1 + (4 - 2 * tClamped) * tClamped
            }
            
            EasingType.EASE_IN_QUAD -> tClamped * tClamped
            EasingType.EASE_OUT_QUAD -> tClamped * (2 - tClamped)
            
            EasingType.EASE_IN_CUBIC -> tClamped * tClamped * tClamped
            EasingType.EASE_OUT_CUBIC -> {
                val t2 = tClamped - 1
                1 + t2 * t2 * t2
            }
            
            EasingType.EASE_IN_BACK -> {
                val c1 = 1.70158f
                val c3 = c1 + 1
                c3 * tClamped * tClamped * tClamped - c1 * tClamped * tClamped
            }
            
            EasingType.EASE_OUT_BACK -> {
                val c1 = 1.70158f
                val c3 = c1 + 1
                1 + c3 * (tClamped - 1) * (tClamped - 1) * (tClamped - 1) + c1 * (tClamped - 1) * (tClamped - 1)
            }
            
            EasingType.EASE_IN_ELASTIC -> {
                if (tClamped == 0f) 0f
                else if (tClamped == 1f) 1f
                else {
                    val c4 = (2 * PI) / 3
                    -(2f.pow(10 * tClamped - 10) * sin((tClamped * 10 - 10.75) * c4)).toFloat()
                }
            }
            
            EasingType.EASE_OUT_ELASTIC -> {
                if (tClamped == 0f) 0f
                else if (tClamped == 1f) 1f
                else {
                    val c4 = (2 * PI) / 3
                    (2f.pow(-10 * tClamped) * sin((tClamped * 10 - 0.75) * c4) + 1).toFloat()
                }
            }
            
            EasingType.EASE_IN_BOUNCE -> 1 - easeValue(1 - tClamped, EasingType.EASE_OUT_BOUNCE)
            EasingType.EASE_OUT_BOUNCE -> outBounce(tClamped)
        }
    }
    
    /**
     * Cria nova animação
     */
    fun createAnimation(
        duration: Long,
        easing: EasingType = EasingType.EASE_OUT,
        onUpdate: (Float) -> Unit,
        onComplete: (() -> Unit)? = null
    ): Animation {
        val anim = if (animationPool.isEmpty()) {
            Animation(duration, easing, onUpdate, onComplete)
        } else {
            animationPool.removeAt(animationPool.size - 1).apply {
                setup(duration, easing, onUpdate, onComplete)
            }
        }
        
        activeAnimations.add(anim)
        return anim
    }
    
    /**
     * Atualiza todas as animações ativas
     */
    fun update() {
        val now = System.currentTimeMillis()
        val delta = now - lastUpdateTime
        lastUpdateTime = now
        
        var i = 0
        while (i < activeAnimations.size) {
            val anim = activeAnimations[i]
            if (anim.update(delta)) {
                // Animação completa
                activeAnimations.removeAt(i)
                animationPool.add(anim)
                if (animationPool.size > 50) {
                    animationPool.removeAt(0)
                }
            } else {
                i++
            }
        }
    }
    
    /**
     Para animação
     */
    fun stop(animation: Animation) {
        activeAnimations.remove(animation)
        animationPool.add(animation)
    }
    
    /**
     * Para todas as animações
     */
    fun stopAll() {
        animationPool.addAll(activeAnimations)
        activeAnimations.clear()
    }
    
    /**
     * Bounce easing helper
     */
    private fun outBounce(t: Float): Float {
        val n1 = 7.5625f
        val d1 = 2.75f
        
        return when {
            t < 1 / d1 -> n1 * t * t
            t < 2 / d1 -> n1 * (t - 1.5f / d1) * (t - 1.5f / d1) + 0.75f
            t < 2.5f / d1 -> n1 * (t - 2.25f / d1) * (t - 2.25f / d1) + 0.9375f
            else -> n1 * (t - 2.625f / d1) * (t - 2.625f / d1) + 0.984375f
        }
    }
    
    /**
     * Power function sem Boxing
     */
    private fun Float.pow(exponent: Float): Double {
        return kotlin.math.pow(this.toDouble(), exponent.toDouble())
    }
}

/**
 * Classe de Animação reutilizável (pooled)
 */
class Animation(
    var duration: Long = 0,
    var easing: AnimationEngine.EasingType = AnimationEngine.EasingType.LINEAR,
    var onUpdate: ((Float) -> Unit)? = null,
    var onComplete: (() -> Unit)? = null
) {
    private var elapsed = 0L
    private var isActive = true
    
    /**
     * Configura animação (reuso)
     */
    fun setup(
        duration: Long,
        easing: AnimationEngine.EasingType,
        onUpdate: ((Float) -> Unit)?,
        onComplete: (() -> Unit)?
    ) {
        this.duration = duration
        this.easing = easing
        this.onUpdate = onUpdate
        this.onComplete = onComplete
        this.elapsed = 0L
        this.isActive = true
    }
    
    /**
     * Atualiza animação, retorna true se completou
     */
    fun update(deltaMs: Long): Boolean {
        if (!isActive) return true
        
        elapsed += deltaMs
        val progress = (elapsed.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
        val easedProgress = AnimationEngine.easeValue(progress, easing)
        
        onUpdate?.invoke(easedProgress)
        
        if (elapsed >= duration) {
            onComplete?.invoke()
            isActive = false
            return true
        }
        
        return false
    }
    
    /**
     * Para a animação
     */
    fun stop() {
        isActive = false
    }
    
    /**
     * Retorna progresso (0-1)
     */
    fun getProgress(): Float {
        return (elapsed.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
    }
    
    /**
     * Verifica se ainda está ativa
     */
    fun isRunning(): Boolean = isActive
}

/**
 * Sequência de animações
 */
class AnimationSequence {
    private val animations = mutableListOf<Pair<Long, () -> Unit>>()
    private var currentIndex = 0
    private var currentAnimStartTime = 0L
    private var isRunning = false
    
    /**
     * Adiciona animação à sequência
     */
    fun addAnimation(duration: Long, block: () -> Unit) {
        animations.add(Pair(duration, block))
    }
    
    /**
     * Inicia sequência
     */
    fun start() {
        isRunning = true
        currentIndex = 0
        currentAnimStartTime = System.currentTimeMillis()
        if (animations.isNotEmpty()) {
            animations[0].second()
        }
    }
    
    /**
     * Atualiza sequência
     */
    fun update() {
        if (!isRunning || animations.isEmpty()) return
        
        val now = System.currentTimeMillis()
        val elapsed = now - currentAnimStartTime
        
        if (elapsed >= animations[currentIndex].first) {
            currentIndex++
            if (currentIndex < animations.size) {
                currentAnimStartTime = now
                animations[currentIndex].second()
            } else {
                isRunning = false
            }
        }
    }
    
    /**
     * Para sequência
     */
    fun stop() {
        isRunning = false
    }
    
    /**
     * Verifica se está rodando
     */
    fun isActive(): Boolean = isRunning
}
