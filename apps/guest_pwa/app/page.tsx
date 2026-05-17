'use client';

import { useState, FormEvent } from 'react';
import { MoraPhoto } from './_components/mora-photo';

type Step = 'invite' | 'name' | 'done' | 'pending';

const FILM_NAME = 'Tobi & Adaeze';
const FRAMES = 24;

export default function JoinPage() {
  const [step, setStep] = useState<Step>('invite');
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const isPrivate = false;

  if (step === 'pending') {
    return (
      <Stage>
        <Header />
        <BottomBlock>
          <Eyebrow>Request sent</Eyebrow>
          <Title>Awaiting approval</Title>
          <Subtitle>The host has been notified. They&apos;ll let you in shortly.</Subtitle>
        </BottomBlock>
      </Stage>
    );
  }

  if (step === 'done') {
    return (
      <Stage>
        <Header />
        <BottomBlock>
          <Eyebrow>You&apos;re in</Eyebrow>
          <Title>Welcome to the film</Title>
          <Subtitle>Your photos will join the shared roll.</Subtitle>
          <div style={{ height: 20 }} />
          <a href="/camera" style={primaryButton}>
            Open camera
          </a>
        </BottomBlock>
      </Stage>
    );
  }

  if (step === 'name') {
    return (
      <Stage>
        <Header />
        <BottomBlock>
          <Eyebrow>You&apos;re joining</Eyebrow>
          <Title>{FILM_NAME}</Title>
          <Subtitle>Add your name so guests know who took the shot.</Subtitle>
          <form
            onSubmit={(e: FormEvent) => {
              e.preventDefault();
              setStep(isPrivate ? 'pending' : 'done');
            }}
            style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10, marginTop: 24 }}
          >
            <input
              autoFocus
              style={input}
              placeholder="Your first name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <input
              style={input}
              placeholder="Phone (optional, for reveal alert)"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              type="tel"
            />
            <button type="submit" style={primaryButton} disabled={!name.trim()}>
              {isPrivate ? 'Request to join' : 'Join film'}
            </button>
          </form>
        </BottomBlock>
      </Stage>
    );
  }

  return (
    <Stage>
      <Header />
      <BottomBlock>
        <Eyebrow>You&apos;re invited to</Eyebrow>
        <Title>{FILM_NAME}</Title>
        <p style={{ marginTop: 14, fontSize: 15, color: 'var(--text-secondary)', maxWidth: 300, lineHeight: 1.5 }}>
          You&apos;ll get{' '}
          <strong style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{FRAMES} frames</strong>. Take your
          camera and shoot the day. The film develops after the party.
        </p>
        <div style={{ height: 24 }} />
        <button type="button" onClick={() => setStep('name')} style={primaryButton}>
          Take your camera
        </button>
        <p style={{ marginTop: 10, fontSize: 12, color: 'var(--text-tertiary)', textAlign: 'center' }}>
          By tapping you&apos;ll allow Mora to use your camera.
        </p>
      </BottomBlock>
    </Stage>
  );
}

// ─── Layout primitives ───

function Stage({ children }: { children: React.ReactNode }) {
  return (
    <main
      className="fade-in"
      style={{
        position: 'relative',
        minHeight: '100dvh',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        backgroundColor: 'var(--bg-base)',
      }}
    >
      {/* Full-bleed warm hero scene */}
      <MoraPhoto seed={42} focal={{ x: 50, y: 40 }} style={{ position: 'absolute', inset: 0 }} />
      {/* Scrim — fades to bg-base for legibility */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(180deg, rgba(15,10,6,0.30) 0%, rgba(15,10,6,0.55) 45%, var(--bg-base) 100%)',
        }}
      />
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', flex: 1 }}>
        {children}
      </div>
    </main>
  );
}

function Header() {
  return (
    <div style={{ padding: '52px 24px 0', display: 'flex', alignItems: 'center', gap: 8 }}>
      <FrameMark />
      <span
        className="mora-display mora-display-italic"
        style={{ fontSize: 22, lineHeight: 1, color: 'var(--text-primary)', fontWeight: 300 }}
      >
        mora
      </span>
    </div>
  );
}

function BottomBlock({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div style={{ padding: '0 24px 36px' }}>{children}</div>
    </div>
  );
}

function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <div className="mora-label" style={{ color: 'var(--accent)', marginBottom: 10 }}>
      {children}
    </div>
  );
}

function Title({ children }: { children: React.ReactNode }) {
  return (
    <h1
      className="mora-display-hero"
      style={{ fontSize: 44, lineHeight: 1.02, margin: 0, color: 'var(--text-primary)' }}
    >
      {children}
    </h1>
  );
}

function Subtitle({ children }: { children: React.ReactNode }) {
  return (
    <p style={{ marginTop: 14, fontSize: 15, color: 'var(--text-secondary)', maxWidth: 300, lineHeight: 1.5 }}>
      {children}
    </p>
  );
}

function FrameMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden>
      <rect x="6" y="4" width="12" height="2.4" rx="1.1" fill="#D9A85C" opacity="0.45" />
      <rect x="4.75" y="7.5" width="14.5" height="13" rx="2.5" fill="none" stroke="#D9A85C" strokeWidth="1.5" />
      <circle cx="12" cy="14" r="2.1" fill="#D9A85C" />
    </svg>
  );
}

// ─── Shared styles ───

const primaryButton: React.CSSProperties = {
  width: '100%',
  height: 56,
  border: 0,
  borderRadius: 999,
  background: 'var(--accent)',
  color: '#1A0E04',
  fontFamily: 'var(--font-body)',
  fontSize: 16,
  fontWeight: 600,
  letterSpacing: '-0.01em',
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  textDecoration: 'none',
};

const input: React.CSSProperties = {
  width: '100%',
  height: 52,
  padding: '0 20px',
  borderRadius: 999,
  border: '1px solid var(--border-emphasis)',
  background: 'rgba(245,239,230,0.04)',
  color: 'var(--text-primary)',
  fontSize: 15,
  outline: 'none',
  fontFamily: 'var(--font-body)',
};
