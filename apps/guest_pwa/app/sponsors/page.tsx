'use client';

import { useState } from 'react';

const theme = {
  bg: '#0F0A06',
  elevated: '#1A130C',
  accent: '#D9A85C',
  fg: '#F5EFE6',
  muted: '#B8A99A',
  tertiary: '#7A6E60',
  border: 'rgba(245,239,230,0.08)',
  borderEm: 'rgba(245,239,230,0.16)',
  fontDisplay: "'Fraunces', Georgia, serif",
  fontBody: "'Switzer', -apple-system, BlinkMacSystemFont, sans-serif",
  fontMono: "'JetBrains Mono', ui-monospace, monospace",
} as const;

const vendors = [
  { name: 'Folake Adisa Textiles', role: 'Aso oke', palette: ['#3A1418', '#D4A857', '#7A3025'] },
  { name: 'Hibiscus & Hay', role: 'Catering', palette: ['#2A1F1A', '#E89C5C', '#4D2A20'] },
  { name: 'Aramide Studio', role: 'Photography', palette: ['#1A1714', '#A88B5C', '#3D3530'] },
  { name: 'Hall One, Ikeja', role: 'Venue', palette: ['#1F2A52', '#D4A857', '#3D3530'] },
];

function SponsoredBadge() {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 8px', borderRadius: 99,
      background: 'rgba(0,0,0,0.35)',
      backdropFilter: 'blur(10px)',
      border: '1px solid rgba(245,239,230,0.10)',
    }}>
      <div style={{ width: 4, height: 4, borderRadius: 1, background: theme.accent }} />
      <span style={{
        fontFamily: theme.fontBody, fontSize: 9, fontWeight: 500,
        letterSpacing: '0.16em', textTransform: 'uppercase',
        color: 'rgba(245,239,230,0.75)',
      }}>Sponsored</span>
    </div>
  );
}

function AsoebiSwatch({ palette }: { palette: string[] }) {
  const [base, glow, lift] = palette;
  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice"
        style={{ width: '100%', height: '100%', display: 'block' }}>
        <defs>
          <radialGradient id={`as-${palette.join('')}`} cx="50%" cy="55%" r="80%">
            <stop offset="0%" stopColor={glow} stopOpacity="0.85" />
            <stop offset="55%" stopColor={base} stopOpacity="0.6" />
            <stop offset="100%" stopColor="#000" stopOpacity="0.65" />
          </radialGradient>
        </defs>
        <rect width="100" height="100" fill={base} />
        <ellipse cx="30" cy="40" rx="40" ry="32" fill={lift} opacity="0.55" filter="url(#bl)" />
        <ellipse cx="75" cy="70" rx="32" ry="40" fill={glow} opacity="0.6" filter="url(#bl)" />
        <rect width="100" height="100" fill={`url(#as-${palette.join('')})`} />
        <filter id="bl"><feGaussianBlur stdDeviation="6" /></filter>
      </svg>
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, rgba(15,10,6,0.10) 0%, rgba(15,10,6,0.75) 100%)',
      }} />
    </div>
  );
}

function SponsoredFrame() {
  return (
    <div style={{ position: 'relative', aspectRatio: '1/1.18', overflow: 'hidden', borderRadius: 2 }}>
      <AsoebiSwatch palette={['#3A1418', '#D4A857', '#7A3025']} />
      <div style={{ position: 'absolute', top: 8, left: 8 }}><SponsoredBadge /></div>
      <div style={{ position: 'absolute', bottom: 10, left: 10, right: 10 }}>
        <div style={{
          fontFamily: theme.fontDisplay, fontSize: 17, lineHeight: 1.05,
          fontStyle: 'italic', color: theme.fg,
        }}>Folake Adisa</div>
        <div style={{ marginTop: 2, fontSize: 10, color: theme.muted }}>Aso oke for the day.</div>
      </div>
    </div>
  );
}

function IssueInsert() {
  return (
    <div style={{
      borderRadius: 4, overflow: 'hidden',
      background: theme.elevated, border: `1px solid ${theme.border}`,
    }}>
      <div style={{ position: 'relative', aspectRatio: '16/9' }}>
        <AsoebiSwatch palette={['#3A1418', '#D4A857', '#7A3025']} />
        <div style={{
          position: 'absolute', top: 12, left: 14, right: 14,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{
            fontFamily: theme.fontMono, fontSize: 9, letterSpacing: '0.16em',
            textTransform: 'uppercase', color: 'rgba(245,239,230,0.55)',
          }}>Insert · No. 03</span>
          <SponsoredBadge />
        </div>
        <div style={{ position: 'absolute', left: 14, right: 14, bottom: 14 }}>
          <div style={{
            fontFamily: theme.fontDisplay, fontSize: 20, lineHeight: 1.05,
            fontStyle: 'italic', color: theme.fg,
          }}>Aso oke, woven slow.</div>
        </div>
      </div>
      <div style={{
        padding: '12px 14px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
      }}>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 12, color: theme.fg, fontWeight: 500, letterSpacing: '-0.01em' }}>
            Folake Adisa Textiles
          </div>
          <div style={{ marginTop: 2, fontSize: 11, color: theme.tertiary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            Hand-loomed in Iseyin. Cut for owambe season.
          </div>
        </div>
        <button style={{
          flexShrink: 0, background: 'transparent',
          border: `1px solid ${theme.borderEm}`,
          color: theme.fg, borderRadius: 99, padding: '7px 14px',
          fontFamily: theme.fontBody, fontSize: 12, fontWeight: 500,
          cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6,
        }}>
          See the cloth <span style={{ fontSize: 12 }}>→</span>
        </button>
      </div>
    </div>
  );
}

function MadePossibleBy() {
  return (
    <div style={{ padding: '24px 20px 20px', borderTop: `1px solid ${theme.border}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <span style={{
          fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase',
          color: theme.accent, fontWeight: 500,
        }}>Made possible by</span>
        <div style={{ flex: 1, height: 1, background: theme.border }} />
        <SponsoredBadge />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {vendors.map((v, i) => (
          <button key={i} style={{
            textAlign: 'left', padding: 10, borderRadius: 14,
            background: theme.elevated, border: `1px solid ${theme.border}`,
            display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer',
          }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, overflow: 'hidden', position: 'relative', flexShrink: 0 }}>
              <AsoebiSwatch palette={v.palette} />
            </div>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{
                fontSize: 12, color: theme.fg, fontWeight: 500,
                letterSpacing: '-0.01em', overflow: 'hidden',
                textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>{v.name}</div>
              <div style={{ marginTop: 1, fontSize: 10, color: theme.tertiary, letterSpacing: '0.04em', textTransform: 'uppercase' }}>
                {v.role}
              </div>
            </div>
          </button>
        ))}
      </div>
      <p style={{
        marginTop: 14, fontSize: 11, color: theme.tertiary,
        lineHeight: 1.5, textAlign: 'center',
      }}>
        Vendors the host tagged. Mora earns a small fee when guests book through these credits.
      </p>
    </div>
  );
}

function SectionHeader({ num, title, hint }: { num: string; title: string; hint: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 12 }}>
      <span style={{
        fontFamily: theme.fontMono, fontSize: 10, letterSpacing: '0.12em', color: theme.accent,
      }}>{num}</span>
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 18, lineHeight: 1.1, color: theme.fg }}>
          {title}
        </div>
        <div style={{ marginTop: 2, fontSize: 11, color: theme.tertiary }}>{hint}</div>
      </div>
    </div>
  );
}

export default function SponsorsPage() {
  const [back] = useState(false);

  return (
    <main style={{
      minHeight: '100dvh', backgroundColor: theme.bg, color: theme.fg,
      fontFamily: theme.fontBody, display: 'flex', flexDirection: 'column',
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '52px 20px 12px',
      }}>
        <button onClick={() => window.history.back()} style={{
          background: 'transparent', border: 0, color: theme.muted,
          padding: 8, marginLeft: -8, cursor: 'pointer',
          display: 'flex', alignItems: 'center',
        }}>
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M15 5l-7 7 7 7" />
          </svg>
        </button>
        <span style={{
          fontSize: 10, letterSpacing: '0.12em',
          color: theme.tertiary, fontWeight: 500,
        }}>Placements</span>
        <div style={{ minWidth: 22 }} />
      </div>

      {/* Scrollable */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {/* Title */}
        <div style={{ padding: '0 20px 28px' }}>
          <h2 style={{
            fontFamily: theme.fontDisplay, fontSize: 26, lineHeight: 1.12,
            margin: 0, fontWeight: 350,
          }}>
            How <em style={{ fontStyle: 'italic' }}>advertising</em><br />lives in Mora
          </h2>
          <p style={{ marginTop: 14, fontSize: 13, color: theme.muted, lineHeight: 1.5 }}>
            Three magazine-insert patterns. No banners, no popups. Each respects the film.
          </p>
        </div>

        {/* 01 */}
        <div style={{ padding: '0 20px 28px' }}>
          <SectionHeader num="01" title="Sponsored frame" hint="A tile in the photo grid." />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, borderRadius: 4, overflow: 'hidden' }}>
            <div style={{ position: 'relative', aspectRatio: '1/1.18', backgroundColor: theme.elevated, borderRadius: 2 }} />
            <SponsoredFrame />
            <div style={{ position: 'relative', aspectRatio: '1/1.18', backgroundColor: theme.elevated, borderRadius: 2 }} />
            <div style={{ position: 'relative', aspectRatio: '1/1.18', backgroundColor: theme.elevated, borderRadius: 2 }} />
          </div>
        </div>

        {/* 02 */}
        <div style={{ padding: '0 20px 28px' }}>
          <SectionHeader num="02" title="Issue insert" hint="Between sections in By-time view." />
          <IssueInsert />
        </div>

        {/* 03 */}
        <div style={{ padding: '0 0 16px' }}>
          <div style={{ padding: '0 20px' }}>
            <SectionHeader num="03" title="Made possible by" hint="Vendor credits at the album foot." />
          </div>
          <MadePossibleBy />
        </div>

        {/* Principle */}
        <div style={{
          margin: '0 20px 28px', padding: 14, borderRadius: 14,
          background: 'rgba(217,168,92,0.06)',
          border: '1px solid rgba(217,168,92,0.20)',
        }}>
          <div style={{
            fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase',
            color: theme.accent, fontWeight: 500, marginBottom: 6,
          }}>Principle</div>
          <p style={{ margin: 0, fontSize: 12, color: theme.muted, lineHeight: 1.55 }}>
            Ads on Mora must be <em>of the event</em>, not <em>at</em> the viewer. We favor vendors that worked the day, magazine-coded layouts, and zero urgency-language. No &ldquo;limited time,&rdquo; no badges, no flashing.
          </p>
        </div>
      </div>
    </main>
  );
}
