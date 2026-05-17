'use client';

import { useRef, useState, useEffect, useCallback } from 'react';
import { MoraPhoto } from '../_components/mora-photo';

const TOTAL = 24;
const FILM_NAME = 'Tobi & Adaeze';

export default function CameraPage() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [flash, setFlash] = useState(false);
  const [shutter, setShutter] = useState(false);
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment');
  const [captured, setCaptured] = useState<string[]>([]);
  const streamRef = useRef<MediaStream | null>(null);

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }, []);

  const startCamera = useCallback(async () => {
    stopStream();
    try {
      const s = await navigator.mediaDevices.getUserMedia({
        video: { facingMode, width: { ideal: 1920 }, height: { ideal: 1080 } },
        audio: false,
      });
      streamRef.current = s;
      if (videoRef.current) videoRef.current.srcObject = s;
    } catch {
      setError('Camera unavailable');
    }
  }, [facingMode, stopStream]);

  useEffect(() => {
    startCamera();
    return stopStream;
  }, [startCamera, stopStream]);

  const takePhoto = () => {
    if (captured.length >= TOTAL) return;
    setShutter(true);
    setTimeout(() => setShutter(false), 180);

    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas || !video.videoWidth) {
      // Fallback so the prototype interactions still work in browsers without
      // a camera permission; bump the counter with a placeholder.
      setCaptured((prev) => [`placeholder:${prev.length}`, ...prev]);
      return;
    }
    canvas.width = video.videoWidth || 1280;
    canvas.height = video.videoHeight || 720;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.drawImage(video, 0, 0);
    const dataUrl = canvas.toDataURL('image/webp', 0.9);
    setCaptured((prev) => [dataUrl, ...prev]);
  };

  const remaining = TOTAL - captured.length;
  const remainingDisplay = String(Math.max(0, remaining)).padStart(2, '0');

  return (
    <main
      style={{
        position: 'relative',
        width: '100%',
        height: '100dvh',
        backgroundColor: '#000',
        overflow: 'hidden',
        fontFamily: 'var(--font-body)',
      }}
    >
      <canvas ref={canvasRef} style={{ display: 'none' }} />

      {/* Viewfinder — real camera if available, warm placeholder otherwise */}
      {error ? (
        <MoraPhoto seed={99} focal={{ x: 48, y: 60 }} style={{ position: 'absolute', inset: 0 }} />
      ) : (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      )}

      {/* Shutter flash */}
      {shutter && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(245,239,230,0.55)',
            zIndex: 30,
            animation: 'mora-shutter 180ms ease-out forwards',
            pointerEvents: 'none',
          }}
        />
      )}

      {/* Top scrim */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: 140,
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.55), rgba(0,0,0,0))',
          pointerEvents: 'none',
        }}
      />

      {/* Top bar — film name pill + flash toggle */}
      <div
        style={{
          position: 'absolute',
          top: 52,
          left: 0,
          right: 0,
          padding: '0 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          zIndex: 10,
        }}
      >
        <a href="/" style={pill()}>
          <FilmIcon />
          <span style={{ fontSize: 12, fontWeight: 500 }}>{FILM_NAME}</span>
        </a>
        <button onClick={() => setFlash((f) => !f)} style={pill(flash ? 'var(--accent)' : undefined)}>
          <FlashIcon active={flash} />
        </button>
      </div>

      {/* Time-to-develop pill */}
      <div
        style={{
          position: 'absolute',
          top: 110,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'center',
          zIndex: 10,
        }}
      >
        <div style={pill()}>
          <ClockIcon />
          <span style={{ fontSize: 11, letterSpacing: '0.04em', color: 'rgba(245,239,230,0.85)' }}>
            Develops in 4h 22m
          </span>
        </div>
      </div>

      {/* Viewfinder reticule corners */}
      <div style={{ position: 'absolute', inset: '32% 18% 38% 18%', pointerEvents: 'none', opacity: 0.55 }}>
        {(['tl', 'tr', 'bl', 'br'] as const).map((c) => (
          <span
            key={c}
            style={{
              position: 'absolute',
              width: 18,
              height: 18,
              top: c.startsWith('t') ? 0 : 'auto',
              bottom: c.startsWith('b') ? 0 : 'auto',
              left: c.endsWith('l') ? 0 : 'auto',
              right: c.endsWith('r') ? 0 : 'auto',
              borderStyle: 'solid',
              borderColor: 'rgba(245,239,230,0.7)',
              borderWidth:
                c === 'tl'
                  ? '1.5px 0 0 1.5px'
                  : c === 'tr'
                  ? '1.5px 1.5px 0 0'
                  : c === 'bl'
                  ? '0 0 1.5px 1.5px'
                  : '0 1.5px 1.5px 0',
            }}
          />
        ))}
      </div>

      {/* Bottom controls */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          padding: '24px 20px 36px',
          background: 'linear-gradient(to top, rgba(0,0,0,0.65), rgba(0,0,0,0))',
          zIndex: 10,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          {/* Frames left */}
          <div style={{ width: 76 }}>
            <div
              className="mora-mono"
              style={{ fontSize: 28, fontWeight: 500, lineHeight: 1, color: 'var(--text-primary)' }}
            >
              <span style={{ color: remaining <= 3 ? 'var(--accent)' : 'var(--text-primary)' }}>
                {remainingDisplay}
              </span>
              <span style={{ color: 'var(--text-tertiary)' }}>/{TOTAL}</span>
            </div>
            <div
              className="mora-label"
              style={{ marginTop: 4, fontSize: 9, color: 'rgba(245,239,230,0.5)' }}
            >
              FRAMES LEFT
            </div>
          </div>

          {/* Shutter */}
          <button
            onClick={takePhoto}
            disabled={remaining <= 0}
            aria-label="Take photo"
            style={{
              appearance: 'none',
              width: 78,
              height: 78,
              borderRadius: '50%',
              background: 'transparent',
              border: 0,
              cursor: remaining <= 0 ? 'not-allowed' : 'pointer',
              position: 'relative',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: 0,
            }}
          >
            <div
              style={{
                position: 'absolute',
                inset: 0,
                borderRadius: '50%',
                border: '2px solid rgba(245,239,230,0.85)',
              }}
            />
            <div
              style={{
                position: 'absolute',
                inset: 6,
                borderRadius: '50%',
                background: 'var(--text-primary)',
                transition: 'transform .12s var(--ease-out)',
                transform: shutter ? 'scale(.86)' : 'scale(1)',
              }}
            />
          </button>

          {/* Recent strip */}
          <div style={{ width: 76, display: 'flex', justifyContent: 'flex-end' }}>
            <div style={{ position: 'relative', width: 56, height: 56 }}>
              {captured.length === 0 ? (
                <div
                  style={{
                    width: 56,
                    height: 56,
                    borderRadius: 12,
                    border: '1px dashed rgba(245,239,230,0.25)',
                  }}
                />
              ) : (
                captured.slice(0, 3).map((url, i) => (
                  <div
                    key={i}
                    style={{
                      position: 'absolute',
                      width: 50,
                      height: 50,
                      borderRadius: 10,
                      overflow: 'hidden',
                      border: '1.5px solid rgba(0,0,0,0.4)',
                      boxShadow: '0 6px 12px rgba(0,0,0,0.5)',
                      left: i * 3,
                      top: i * -3,
                      zIndex: 10 - i,
                    }}
                  >
                    {url.startsWith('placeholder:') ? (
                      <MoraPhoto seed={3 + i * 4} style={{ width: '100%', height: '100%' }} />
                    ) : (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={url}
                        alt=""
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      />
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* Flip / done row */}
        <div
          style={{
            marginTop: 18,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
          }}
        >
          <button
            onClick={() => setFacingMode((m) => (m === 'environment' ? 'user' : 'environment'))}
            style={pill()}
          >
            <FlipIcon />
            <span style={{ fontSize: 12, color: 'rgba(245,239,230,0.85)' }}>Flip</span>
          </button>
          <a href="/thanks" style={pill()}>
            <span style={{ fontSize: 12, color: 'rgba(245,239,230,0.85)' }}>Done</span>
            <ChevronIcon />
          </a>
        </div>
      </div>
    </main>
  );
}

function pill(bg?: string): React.CSSProperties {
  return {
    appearance: 'none',
    background: bg ?? 'rgba(0,0,0,0.4)',
    backdropFilter: 'blur(12px)',
    WebkitBackdropFilter: 'blur(12px)',
    border: '1px solid rgba(255,255,255,0.12)',
    borderRadius: 99,
    padding: '8px 12px',
    color: bg === 'var(--accent)' ? '#1A0E04' : 'rgba(255,255,255,0.92)',
    cursor: 'pointer',
    display: 'inline-flex',
    alignItems: 'center',
    gap: 6,
    fontFamily: 'var(--font-body)',
    textDecoration: 'none',
  };
}

function FilmIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
      <rect x="3" y="6" width="18" height="14" rx="2" />
      <circle cx="12" cy="13" r="2.5" fill="currentColor" stroke="none" />
    </svg>
  );
}
function FlashIcon({ active }: { active: boolean }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round">
      <path d="M13 3 4 14h6l-1 7 9-11h-6l1-7Z" />
    </svg>
  );
}
function ClockIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" strokeLinecap="round" />
    </svg>
  );
}
function FlipIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12a8 8 0 0 1 13-6l3 3" />
      <path d="M20 12a8 8 0 0 1-13 6l-3-3" />
      <path d="M17 3v6h-6" />
      <path d="M7 21v-6h6" />
    </svg>
  );
}
function ChevronIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="m9 6 6 6-6 6" />
    </svg>
  );
}
