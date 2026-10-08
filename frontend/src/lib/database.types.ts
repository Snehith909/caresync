export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Medication = {
  name: string;
  strength: string;
  directions: string;
};

type TimestampedRow = {
  id: string;
  doctor_id: string;
  created_at: string;
  updated_at: string;
};

type Table<Row, Insert, Update = Partial<Insert>> = {
  Row: Row;
  Insert: Insert;
  Update: Update;
  Relationships: [];
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: { user_id: string; display_name: string; role: "doctor"; active: boolean; created_at: string };
        Insert: { user_id: string; display_name: string; role?: "doctor"; active?: boolean };
        Update: never;
        Relationships: [];
      };
      patients: {
        Row: {
          id: string; doctor_id: string; name: string; age: number; gender: string; condition: string;
          phone: string; nominee: string; nominee_relation: string; follow_up: string | null;
          adherence_percent: number | null; created_at: string; updated_at: string;
        };
        Insert: {
          doctor_id: string; name: string; age: number; gender: string; condition: string;
          phone: string; nominee: string; nominee_relation: string; follow_up?: string | null;
          adherence_percent?: number | null;
        };
        Update: {
          name?: string; age?: number; gender?: string; condition?: string; phone?: string;
          nominee?: string; nominee_relation?: string; follow_up?: string | null;
          adherence_percent?: number | null;
        };
        Relationships: [];
      };
      care_plans: {
        Row: {
          id: string; patient_id: string; doctor_id: string; version: number; status: string;
          notes: string; source_path: string; medications: Medication[]; is_reassessment: boolean;
          created_at: string; updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      alerts: {
        Row: {
          id: string; patient_id: string; doctor_id: string; reason: string; detail: string;
          severity: "urgent" | "warning" | "info"; status: "open" | "acknowledged" | "resolved";
          created_at: string; updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      audit_events: {
        Row: {
          id: string; doctor_id: string; action: string; entity_type: string;
          entity_id: string; created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      appointments: Table<TimestampedRow & {
        patient_id: string; starts_at: string; ends_at: string;
        status: "scheduled" | "checked_in" | "in_consultation" | "completed" | "cancelled" | "no_show";
        reason: string;
      }, {
        doctor_id: string; patient_id: string; starts_at: string; ends_at: string;
        status?: "scheduled" | "checked_in" | "in_consultation" | "completed" | "cancelled" | "no_show";
        reason?: string;
      }>;
      queue_entries: Table<TimestampedRow & {
        patient_id: string; appointment_id: string | null; queue_date: string; token_number: number;
        status: "waiting" | "consulting" | "completed" | "cancelled";
        checked_in_at: string; started_at: string | null; completed_at: string | null;
      }, {
        doctor_id: string; patient_id: string; appointment_id?: string | null; queue_date?: string;
        token_number: number; status?: "waiting" | "consulting" | "completed" | "cancelled";
        checked_in_at?: string; started_at?: string | null; completed_at?: string | null;
      }>;
      consultations: Table<TimestampedRow & {
        patient_id: string; appointment_id: string | null; queue_entry_id: string | null;
        symptoms: string; notes: string; diagnosis: string; treatment_plan: string; follow_up_date: string | null;
      }, {
        doctor_id: string; patient_id: string; appointment_id?: string | null; queue_entry_id?: string | null;
        symptoms?: string; notes?: string; diagnosis?: string; treatment_plan?: string; follow_up_date?: string | null;
      }>;
      prescriptions: Table<TimestampedRow & { consultation_id: string }, {
        doctor_id: string; consultation_id: string;
      }>;
      medications: Table<TimestampedRow & {
        prescription_id: string; name: string; dosage: string; frequency: string; duration: string; instructions: string;
      }, {
        doctor_id: string; prescription_id: string; name: string; dosage: string;
        frequency: string; duration: string; instructions?: string;
      }>;
      lab_reports: Table<TimestampedRow & {
        patient_id: string; storage_path: string; report_type: string;
        status: "uploaded" | "processing" | "reviewed" | "failed";
        extracted_values: Json[]; abnormal_flags: Json[]; collected_at: string | null;
      }, {
        doctor_id: string; patient_id: string; storage_path: string; report_type?: string;
        status?: "uploaded" | "processing" | "reviewed" | "failed";
        extracted_values?: Json[]; abnormal_flags?: Json[]; collected_at?: string | null;
      }>;
      vitals: Table<TimestampedRow & {
        patient_id: string; measured_at: string; systolic: number | null; diastolic: number | null;
        heart_rate: number | null; temperature_c: number | null; respiratory_rate: number | null;
        oxygen_saturation: number | null; weight_kg: number | null; height_cm: number | null; notes: string;
      }, {
        doctor_id: string; patient_id: string; measured_at?: string; systolic?: number | null;
        diastolic?: number | null; heart_rate?: number | null; temperature_c?: number | null;
        respiratory_rate?: number | null; oxygen_saturation?: number | null; weight_kg?: number | null;
        height_cm?: number | null; notes?: string;
      }>;
      allergies: Table<TimestampedRow & {
        patient_id: string; substance: string; reaction: string;
        severity: "unknown" | "mild" | "moderate" | "severe"; recorded_at: string;
      }, {
        doctor_id: string; patient_id: string; substance: string; reaction?: string;
        severity?: "unknown" | "mild" | "moderate" | "severe"; recorded_at?: string;
      }>;
      medical_history: Table<TimestampedRow & {
        patient_id: string; category: string; description: string; recorded_at: string;
      }, {
        doctor_id: string; patient_id: string; category: string; description: string; recorded_at?: string;
      }>;
      follow_ups: Table<TimestampedRow & {
        patient_id: string; consultation_id: string | null; due_at: string;
        status: "scheduled" | "completed" | "cancelled" | "overdue"; notes: string;
      }, {
        doctor_id: string; patient_id: string; consultation_id?: string | null; due_at: string;
        status?: "scheduled" | "completed" | "cancelled" | "overdue"; notes?: string;
      }>;
      notifications: Table<TimestampedRow & {
        patient_id: string | null; kind: "appointment_reminder" | "follow_up_reminder" | "queue_update" | "other";
        title: string; body: string; scheduled_at: string | null; sent_at: string | null; read_at: string | null;
      }, {
        doctor_id: string; patient_id?: string | null;
        kind: "appointment_reminder" | "follow_up_reminder" | "queue_update" | "other";
        title: string; body?: string; scheduled_at?: string | null; sent_at?: string | null; read_at?: string | null;
      }>;
    };
    Views: Record<string, never>;
    Functions: {
      create_care_plan_draft: {
        Args: { p_patient_id: string; p_notes: string; p_source_path: string; p_medications: Medication[] };
        Returns: string;
      };
      act_on_care_plan: {
        Args: { p_plan_id: string; p_action: "approve" | "correction" | "reject" };
        Returns: undefined;
      };
      acknowledge_alert: { Args: { p_alert_id: string }; Returns: undefined };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
