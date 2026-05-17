'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { MoraPhoto } from '../_components/mora-photo';

const FILM_NAME = 'Tobi & Adaeze';
const FRAME_COUNT = 28;
const GUEST_COUNT = 12;
const PHOTO_SEEDS = [11, 22, 5, 31, 17, 8, 44, 3, 26, 14, 9, 38];

type Stage = 'countdown' | 'revealing' | 'revealed';

export default function DevelopPage() {
  const router = useRouter();
  const [stage, setStage] = useState<Stage>('countdown');
  const [count, setCount] = useState(3);

  useEffect(() => {
    let t: ReturnType<typeof setTimeout> | undefined;
    if (stage === 'countdown') {
      if (count > 1) {
        t = setTimeout(() => setCount((c) => c - 1), 900);
      } else {
        t = setTimeout(() => setStage('revealing'), 900);
      }
    } else if (stage === 'revealing') {
      t = setTimeout(() => setStage('revealed'), 2600);
    }
    return () => {
      if (t) clearTimeout(t);
    };
  }, [stage, count]);

  if (stage === 'revealed') {
    return <RevealedHero filmName={FILM_NAME} onOpen={() => router.push('/album')} />;
  }

  const revealing = stage !== 'countdown';

  return (
    <main
      className="fade-in"
      style={{
        position: 'relative',
        minHeight: '100dvh',
        background: 'var(--bg-base)',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        fontFamily: 'var(--font-body)',
      }}
    >
      {/* Warm accent halo behind the grid */}
      <div
        style={{
          position: 'absolute',
          inset: '-20%',
          background:
            'radial-gradient(50% 40% at 50% 45%, rgba(217,168,92,0.22) 0%, rgba(217,168,92,0) 60%)',
          opacity: revealing ? 1 : 0.35,
          transition: 'opacity 1.6s var(--ease-reveal)',
          pointerEvents: 'none',
        }}
      />

      {/* Header */}
      <div style={{ padding: '64px 20px 0', textAlign: 'center', zIndex: 5, position: 'relative' }}>
        <div
          className="mora-label"
          style={{
            color: 'var(--accent)',
            opacity: stage === 'countdown' ? 1 : 0,
            transition: 'opacity 0.6s var(--ease-out)',
          }}
        >
          Your film is developing
        </div>
        <h2
          className="mora-display"
          style={{ fontSize: 26, lineHeight: 1.1, margin: '14px 0 0', color: 'var(--text-primary)' }}
        >
          {FILM_NAME}
        </h2>
        <div style={{ marginTop: 6, fontSize: 13, color: 'var(--text-secondary)' }}>
          {FRAME_COUNT} frames from {GUEST_COUNT} guests
        </div>
      </div>

      {/* Photo grid with staggered develop */}
      <div
        style={{
          flex: 1,
          padding: '36px 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          width: '100%',
        }}
      >
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 4,
            width: '100%',
            maxWidth: 340,
          }}
        >
          {PHOTO_SEEDS.map((s, i) => {
            const delay = i * 130;
            return (
              <div
                key={i}
                style={{
                  position: 'relative',
                  aspectRatio: '1/1.25',
                  overflow: 'hidden',
                  borderRadius: 4,
                  opacity: revealing ? 1 : 0,
                  transform: revealing ? 'scale(1)' : 'scale(0.94)',
                  filter: revealing
                    ? 'blur(0px) saturate(1)'
                    : 'blur(16px) saturate(0.5)',
                  transition: `opacity 1.4s var(--ease-reveal) ${delay}ms, transform 1.6s var(--ease-reveal) ${delay}ms, filter 1.8s var(--ease-reveal) ${delay}ms`,
                }}
              >
                <MoraPhoto seed={s} style={{ position: 'absolute', inset: 0 }} />
              </div>
            );
          })}
        </div>
      </div>

      {/* Countdown overlay */}
      {stage === 'countdown' && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background:
              'radial-gradient(50% 50% at 50% 55%, rgba(15,10,6,0.45) 0%, rgba(15,10,6,0.9) 100%)',
            zIndex: 6,
          }}
        >
          <div style={{ textAlign: 'center' }}>
            <div className="mora-label" style={{ marginBottom: 18, color: 'var(--accent)' }}>
              Developing in
            </div>
            <div
              key={count}
              className="mora-display-hero fade-in"
              style={{ fontSize: 124, lineHeight: 1, color: 'var(--text-primary)', fontWeight: 300 }}
            >
              {count}
            </div>
          </div>
        </div>
      )}
    </main>
  );
}

function RevealedHero({ filmName, onOpen }: { filmName: string; onOpen: () => void }) {
  return (
    <main
      className="fade-in"
      style={{
        position: 'relative',
        minHeight: '100dvh',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        fontFamily: 'var(--font-body)',
      }}
    >
      <MoraPhoto seed={22} focal={{ x: 50, y: 38 }} style={{ position: 'absolute', inset: 0 }} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(180deg, rgba(15,10,6,0.10) 0%, rgba(15,10,6,0.4) 45%, rgba(15,10,6,0.95) 100%)',
        }}
      />
      <div style={{ flex: 1 }} />
      <div style={{ padding: '0 24px 40px', position: 'relative' }}>
        <div className="mora-label" style={{ marginBottom: 10, color: 'var(--accent)' }}>
          Your film is ready
        </div>
        <h2
          className="mora-display-hero"
          style={{ fontSize: 40, lineHeight: 1.02, margin: 0, color: 'var(--text-primary)' }}
        >
          {filmName}
        </h2>
        <p
          style={{
            marginTop: 10,
            fontSize: 14,
            color: 'var(--text-secondary)',
            maxWidth: 280,
          }}
        >
          28 frames · 12 guests · Saturday in Lagos
        </p>
        <button
          onClick={onOpen}
          style={{
            marginTop: 22,
            width: '100%',
            height: 56,
            border: 0,
            borderRadius: 999,
            background: 'var(--accent)',
            color: '#1A0E04',
            fontFamily: 'var(--font-body)',
            fontSize: 16,
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          Open film
        </button>
      </div>
    </main>
  );
}
