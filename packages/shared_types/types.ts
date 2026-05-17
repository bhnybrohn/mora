export type EventType = 'wedding' | 'owambe' | 'naming' | 'funeral' | 'birthday' | 'other';

export type EventPrivacy = 'public' | 'private';

export type EventStatus = 'active' | 'revealed' | 'archived';

export type EventTier = 'free' | 'standard' | 'premium';

export type JoinRequestStatus = 'pending' | 'approved' | 'rejected';

export interface Event {
  id: string;
  owner_user_id: string;
  name: string;
  event_type: EventType;
  privacy: EventPrivacy;
  starts_at: string;
  ends_at: string;
  reveal_at: string;
  tier: EventTier;
  status: EventStatus;
  guest_count: number;
  photo_count: number;
  created_at: string;
}

export interface Guest {
  id: string;
  event_id: string;
  display_name: string;
  phone?: string;
  joined_at: string;
  kicked_at?: string;
  photo_count: number;
}

export interface JoinRequest {
  id: string;
  event_id: string;
  display_name: string;
  phone?: string;
  status: JoinRequestStatus;
  requested_at: string;
}

export interface Photo {
  id: string;
  event_id: string;
  guest_id?: string;
  storage_key: string;
  preview_key: string;
  width: number;
  height: number;
  taken_at: string;
  status: string;
}

export interface Payment {
  id: string;
  event_id: string;
  provider: string;
  provider_ref: string;
  amount: number;
  currency: string;
  status: string;
  created_at: string;
}
