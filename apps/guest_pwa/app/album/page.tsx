'use client';

import { useState } from 'react';
import Link from 'next/link';
import { MoraPhoto } from '../_components/mora-photo';

const FILM_NAME = 'Tobi & Adaeze';
const SEEDS = [12, 5, 27, 18, 33, 9, 41, 14, 22, 7, 36, 19, 11, 28, 4, 31, 16, 25, 8, 39, 13, 21, 6, 30];

type Tab = 'all' | 'guest' | 'time';

export default function AlbumPage() {
  const [tab, setTab] = useState<Tab>('all');

  return (
    <main
      className="fade-in"
      style={{
        position: 'relative',
        minHeight: '100dvh',
        background: 'var(--bg-base)',
        color: 'var(--text-primary)',
        fontFamily: 'var(--font-body)',
      }}
    >
      <div className="no-scrollbar" style={{ overflow: 'auto' }}>
        {/* Hero — magazine masthead */}
        <div style={{ position: 'relative', height: 320 }}>
          <MoraPhoto seed={12} focal={{ x: 50, y: 45 }} style={{ position: 'absolute', inset: 0 }} />
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background:
                'linear-gradient(180deg, rgba(15,10,6,0.55) 0%, rgba(15,10,6,0.1) 35%, rgba(15,10,6,0.95) 100%)',
            }}
          />

          {/* Top nav */}
          <div
            style={{
              position: 'absolute',
              top: 56,
              left: 0,
              right: 0,
              padding: '0 16px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              zIndex: 10,
            }}
          >
            <Link href="/" style={circleButton}>
              <ChevronLeft />
            </Link>
            <button style={circleButton} aria-label="Share">
              <ShareIcon />
            </button>
          </div>

          {/* Title block — magazine masthead */}
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: 16, padding: '0 20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <span
                className="mora-mono"
                style={{
                  fontSize: 10,
                  letterSpacing: '0.12em',
                  color: 'var(--accent)',
                  textTransform: 'uppercase',
                }}
              >
                Vol. 01 · Owambe · Lagos
              </span>
              <div style={{ flex: 1, height: 1, background: 'rgba(217,168,92,0.35)' }} />
              <span
                className="mora-mono"
                style={{
                  fontSize: 10,
                  letterSpacing: '0.12em',
                  color: 'var(--accent)',
                  textTransform: 'uppercase',
                }}
              >
                14 · vi · 26
              </span>
            </div>
            <h1
              className="mora-display-hero mora-display-italic"
              style={{
                fontSize: 42,
                lineHeight: 0.98,
                margin: 0,
                color: 'var(--text-primary)',
              }}
            >
              {FILM_NAME}
            </h1>
            <div
              style={{
                marginTop: 10,
                fontSize: 13,
                color: 'var(--text-secondary)',
                display: 'flex',
                alignItems: 'center',
                gap: 10,
              }}
            >
              <PeopleIcon />
              <span>12 guests</span>
              <span style={{ color: 'var(--text-disabled)' }}>·</span>
              <span>28 frames</span>
              <span style={{ color: 'var(--text-disabled)' }}>·</span>
              <span>Hosted by Giulio</span>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div
          style={{
            position: 'sticky',
            top: 0,
            zIndex: 5,
            background: 'linear-gradient(to bottom, var(--bg-base) 70%, rgba(15,10,6,0))',
            padding: '14px 20px 10px',
          }}
        >
          <div style={{ display: 'flex', gap: 6 }}>
            {(
              [
                { id: 'all', label: 'All' },
                { id: 'guest', label: 'By guest' },
                { id: 'time', label: 'By time' },
              ] as const
            ).map((t) => {
              const sel = tab === t.id;
              return (
                <button
                  key={t.id}
                  onClick={() => setTab(t.id)}
                  style={{
                    appearance: 'none',
                    background: sel ? 'var(--bg-overlay)' : 'transparent',
                    border: `1px solid ${sel ? 'var(--border-emphasis)' : 'var(--border-subtle)'}`,
                    color: sel ? 'var(--text-primary)' : 'var(--text-secondary)',
                    fontFamily: 'var(--font-body)',
                    fontWeight: 500,
                    borderRadius: 99,
                    padding: '8px 14px',
                    fontSize: 13,
                    cursor: 'pointer',
                  }}
                >
                  {t.label}
                </button>
              );
            })}
            <div style={{ flex: 1 }} />
            <button style={iconChip} aria-label="Guests">
              <PeopleIcon />
            </button>
          </div>
        </div>

        {/* Photo grid */}
        <div style={{ padding: '0 0 24px' }}>
          {tab === 'guest' ? (
            <AlbumByGuest seeds={SEEDS} />
          ) : tab === 'time' ? (
            <AlbumByTime seeds={SEEDS} />
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 2 }}>
              {SEEDS.map((s, i) => {
                if (i === 6) {
                  return (
                    <>
                      <SponsoredFrame key={`sp-${i}`} />
                      <div key={i} style={{ position: 'relative', aspectRatio: '1/1.18' }}>
                        <MoraPhoto seed={s} style={{ position: 'absolute', inset: 0 }} />
                      </div>
                    </>
                  );
                }
                return (
                  <div key={i} style={{ position: 'relative', aspectRatio: '1/1.18' }}>
                    <MoraPhoto seed={s} style={{ position: 'absolute', inset: 0 }} />
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <MadePossibleBy />
        <div style={{ height: 80 }} />
      </div>

      {/* Floating download */}
      <div
        style={{
          position: 'fixed',
          bottom: 32,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'center',
          zIndex: 20,
          pointerEvents: 'none',
        }}
      >
        <button
          style={{
            pointerEvents: 'auto',
            appearance: 'none',
            border: 0,
            height: 48,
            borderRadius: 999,
            padding: '0 22px',
            background: 'var(--accent)',
            color: '#1A0E04',
            fontFamily: 'var(--font-body)',
            fontWeight: 600,
            fontSize: 14,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            cursor: 'pointer',
            boxShadow:
              '0 14px 32px rgba(217,168,92,0.32), 0 4px 8px rgba(0,0,0,0.4)',
          }}
        >
          <DownloadIcon />
          Download all
        </button>
      </div>
    </main>
  );
}

// ─── Layouts inside the album ───

function AlbumByGuest({ seeds }: { seeds: number[] }) {
  const guests: Array<{ name: string; count: number; role?: 'host' | 'watch'; s: number[] }> = [
    { name: 'Adaeze', count: 4, role: 'host', s: [0, 1, 2, 3] },
    { name: 'Auntie Yemi', count: 6, s: [4, 5, 6, 7, 8, 9] },
    { name: 'Tunde', count: 5, s: [10, 11, 12, 13, 14] },
    { name: 'Chinyere', count: 4, s: [15, 16, 17, 18] },
    { name: 'Diaspora · NYC', count: 5, role: 'watch', s: [19, 20, 21, 22, 23] },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, padding: '0 20px' }}>
      {guests.map((g, gi) => (
        <div key={gi}>
          <div
            style={{
              display: 'flex',
              alignItems: 'baseline',
              justifyContent: 'space-between',
              marginBottom: 10,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
              <span
                className="mora-display"
                style={{ fontSize: 18, color: 'var(--text-primary)' }}
              >
                {g.name}
              </span>
              {g.role === 'host' && (
                <span className="mora-label" style={{ color: 'var(--accent)' }}>
                  Host
                </span>
              )}
              {g.role === 'watch' && (
                <span className="mora-label" style={{ color: 'var(--text-tertiary)' }}>
                  Watching
                </span>
              )}
            </div>
            <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>{g.count} frames</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 2 }}>
            {g.s.map((idx, i) => (
              <div key={i} style={{ position: 'relative', aspectRatio: '1' }}>
                <MoraPhoto seed={seeds[idx]} style={{ position: 'absolute', inset: 0 }} />
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function AlbumByTime({ seeds }: { seeds: number[] }) {
  const sections = [
    { time: '11:14 AM', label: 'Arrivals', s: [0, 1, 2, 3, 4] },
    { time: '01:02 PM', label: 'Engagement', s: [5, 6, 7, 8] },
    { time: '03:46 PM', label: 'First dance', s: [9, 10, 11, 12, 13, 14] },
    { time: '06:18 PM', label: 'Asoebi line', s: [15, 16, 17, 18, 19] },
    { time: '09:55 PM', label: 'Late night', s: [20, 21, 22, 23] },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 22, padding: '0 20px' }}>
      {sections.map((sec, si) => (
        <div key={si}>
          <div>
            <div
              style={{
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                marginBottom: 10,
              }}
            >
              <span className="mora-display" style={{ fontSize: 18 }}>
                {sec.label}
              </span>
              <span className="mora-mono" style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                {sec.time}
              </span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 2 }}>
              {sec.s.map((idx, i) => (
                <div key={i} style={{ position: 'relative', aspectRatio: '1' }}>
                  <MoraPhoto seed={seeds[idx]} style={{ position: 'absolute', inset: 0 }} />
                </div>
              ))}
            </div>
          </div>
          {si === 1 && (
            <div style={{ marginTop: 22 }}>
              <IssueInsert />
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ─── Sponsor inserts (mirror of design's three treatments) ───

function SponsoredFrame() {
  return (
    <div style={{ position: 'relative', aspectRatio: '1/1.18', overflow: 'hidden' }}>
      <AsoebiSwatch palette={['#3A1418', '#D4A857', '#7A3025']} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'linear-gradient(180deg, rgba(15,10,6,0.10) 0%, rgba(15,10,6,0.75) 100%)',
        }}
      />
      <div style={{ position: 'absolute', top: 8, left: 8 }}>
        <SponsoredMark />
      </div>
      <div style={{ position: 'absolute', bottom: 10, left: 10, right: 10 }}>
        <div
          className="mora-display mora-display-italic"
          style={{ fontSize: 17, lineHeight: 1.05, color: 'var(--text-primary)' }}
        >
          Folake Adisa
        </div>
        <div style={{ marginTop: 2, fontSize: 10, color: 'var(--text-secondary)' }}>
          Aso oke for the day.
        </div>
      </div>
    </div>
  );
}

function IssueInsert() {
  return (
    <div
      style={{
        borderRadius: 4,
        overflow: 'hidden',
        background: 'var(--bg-elevated)',
        border: '1px solid var(--border-subtle)',
      }}
    >
      <div style={{ position: 'relative', aspectRatio: '16/9' }}>
        <AsoebiSwatch palette={['#3A1418', '#D4A857', '#7A3025']} />
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background:
              'linear-gradient(105deg, rgba(15,10,6,0.55) 0%, rgba(15,10,6,0.05) 60%)',
          }}
        />
        <div
          style={{
            position: 'absolute',
            top: 12,
            left: 14,
            right: 14,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <span
            className="mora-mono"
            style={{
              fontSize: 9,
              letterSpacing: '0.16em',
              textTransform: 'uppercase',
              color: 'rgba(245,239,230,0.55)',
            }}
          >
            Insert · No. 03
          </span>
          <SponsoredMark />
        </div>
        <div style={{ position: 'absolute', left: 14, right: 14, bottom: 14 }}>
          <div
            className="mora-display mora-display-italic"
            style={{ fontSize: 20, lineHeight: 1.05, color: 'var(--text-primary)' }}
          >
            Aso oke, woven slow.
          </div>
        </div>
      </div>
      <div
        style={{
          padding: '12px 14px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <div style={{ minWidth: 0 }}>
          <div
            style={{
              fontSize: 12,
              color: 'var(--text-primary)',
              fontWeight: 500,
              letterSpacing: '-0.01em',
            }}
          >
            Folake Adisa Textiles
          </div>
          <div
            style={{
              marginTop: 2,
              fontSize: 11,
              color: 'var(--text-tertiary)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            Hand-loomed in Iseyin. Cut for owambe season.
          </div>
        </div>
        <button
          style={{
            flexShrink: 0,
            background: 'transparent',
            border: '1px solid var(--border-emphasis)',
            color: 'var(--text-primary)',
            borderRadius: 99,
            padding: '7px 14px',
            fontFamily: 'var(--font-body)',
            fontSize: 12,
            fontWeight: 500,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          See the cloth →
        </button>
      </div>
    </div>
  );
}

function MadePossibleBy() {
  const vendors = [
    { name: 'Folake Adisa Textiles', role: 'Aso oke', palette: ['#3A1418', '#D4A857', '#7A3025'] },
    { name: 'Hibiscus & Hay', role: 'Catering', palette: ['#2A1F1A', '#E89C5C', '#4D2A20'] },
    { name: 'Aramide Studio', role: 'Photography', palette: ['#1A1714', '#A88B5C', '#3D3530'] },
    { name: 'Hall One, Ikeja', role: 'Venue', palette: ['#1F2A52', '#D4A857', '#3D3530'] },
  ];
  return (
    <div
      style={{
        padding: '24px 20px 20px',
        borderTop: '1px solid var(--border-subtle)',
        background: 'var(--bg-base)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <span className="mora-label" style={{ color: 'var(--accent)' }}>
          Made possible by
        </span>
        <div style={{ flex: 1, height: 1, background: 'var(--border-subtle)' }} />
        <SponsoredMark />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {vendors.map((v, i) => (
          <div
            key={i}
            style={{
              padding: 10,
              borderRadius: 14,
              background: 'var(--bg-elevated)',
              border: '1px solid var(--border-subtle)',
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: 10,
                overflow: 'hidden',
                position: 'relative',
                flexShrink: 0,
              }}
            >
              <AsoebiSwatch palette={v.palette} />
            </div>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div
                style={{
                  fontSize: 12,
                  color: 'var(--text-primary)',
                  fontWeight: 500,
                  letterSpacing: '-0.01em',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {v.name}
              </div>
              <div className="mora-label" style={{ marginTop: 1, fontSize: 10 }}>
                {v.role}
              </div>
            </div>
          </div>
        ))}
      </div>
      <p
        style={{
          marginTop: 14,
          fontSize: 11,
          color: 'var(--text-tertiary)',
          lineHeight: 1.5,
          textAlign: 'center',
        }}
      >
        Vendors the host tagged. Mora earns a small fee when guests book through these credits.
      </p>
    </div>
  );
}

function AsoebiSwatch({ palette }: { palette: string[] }) {
  const [base, glow, lift] = palette;
  const id = `as-${palette.join('')}`;
  return (
    <svg
      viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMid slice"
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block' }}
      aria-hidden
    >
      <defs>
        <radialGradient id={id} cx="50%" cy="55%" r="80%">
          <stop offset="0%" stopColor={glow} stopOpacity="0.85" />
          <stop offset="55%" stopColor={base} stopOpacity="0.6" />
          <stop offset="100%" stopColor="#000" stopOpacity="0.65" />
        </radialGradient>
        <filter id={`${id}-bl`}>
          <feGaussianBlur stdDeviation="6" />
        </filter>
      </defs>
      <rect width="100" height="100" fill={base} />
      <ellipse cx="30" cy="40" rx="40" ry="32" fill={lift} opacity="0.55" filter={`url(#${id}-bl)`} />
      <ellipse cx="75" cy="70" rx="32" ry="40" fill={glow} opacity="0.6" filter={`url(#${id}-bl)`} />
      <rect width="100" height="100" fill={`url(#${id})`} />
    </svg>
  );
}

function SponsoredMark() {
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '4px 8px',
        borderRadius: 99,
        background: 'rgba(0,0,0,0.35)',
        backdropFilter: 'blur(10px)',
        WebkitBackdropFilter: 'blur(10px)',
        border: '1px solid rgba(245,239,230,0.10)',
      }}
    >
      <div style={{ width: 4, height: 4, borderRadius: 1, background: 'var(--accent)' }} />
      <span
        className="mora-label"
        style={{ fontSize: 9, color: 'rgba(245,239,230,0.75)' }}
      >
        Sponsored
      </span>
    </div>
  );
}

// ─── Tiny icons ───

const circleButton: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  background: 'rgba(0,0,0,0.32)',
  backdropFilter: 'blur(12px)',
  WebkitBackdropFilter: 'blur(12px)',
  border: '1px solid rgba(255,255,255,0.10)',
  borderRadius: 99,
  padding: 8,
  color: 'rgba(245,239,230,0.92)',
  cursor: 'pointer',
  textDecoration: 'none',
};

const iconChip: React.CSSProperties = {
  appearance: 'none',
  background: 'transparent',
  border: '1px solid var(--border-subtle)',
  borderRadius: 99,
  padding: 8,
  color: 'var(--text-secondary)',
  cursor: 'pointer',
  display: 'flex',
};

function ChevronLeft() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="m15 6-6 6 6 6" />
    </svg>
  );
}
function ShareIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v12" />
      <path d="m7 8 5-5 5 5" />
      <rect x="4" y="13" width="16" height="8" rx="2" />
    </svg>
  );
}
function PeopleIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="8" r="3.2" />
      <path d="M3 20a6 6 0 0 1 12 0" />
      <circle cx="17" cy="9" r="2.6" />
      <path d="M15 20a5 5 0 0 1 8 0" />
    </svg>
  );
}
function DownloadIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 4v12" />
      <path d="m7 12 5 5 5-5" />
      <path d="M5 21h14" />
    </svg>
  );
}
