import type { User } from "@supabase/supabase-js";
import type { Database, Medication } from "../lib/database.types";
import { requireSupabaseClient } from "./api/client";

type PatientRow = Database["public"]["Tables"]["patients"]["Row"];
type PlanRow = Database["public"]["Tables"]["care_plans"]["Row"];
type AlertRow = Database["public"]["Tables"]["alerts"]["Row"];

export type PatientRecord = PatientRow;
export type CarePlanRecord = PlanRow;
export type AlertRecord = AlertRow;

export type WorkspaceData = {
  patients: PatientRow[];
  plans: PlanRow[];
  alerts: AlertRow[];
};

const throwIfError = <T,>(result: { data: T | null; error: { message: string } | null }): T => {
  if (result.error) throw new Error(result.error.message);
  if (result.data === null) throw new Error("Supabase returned no data for this operation.");
  return result.data;
};

export async function loadWorkspace(): Promise<WorkspaceData> {
  const client = requireSupabaseClient();
  const [patientsResult, plansResult, alertsResult] = await Promise.all([
    client.from("patients").select("*").order("created_at", { ascending: false }),
    client.from("care_plans").select("*").order("created_at", { ascending: false }),
    client.from("alerts").select("*").order("created_at", { ascending: false }),
  ]);
  return {
    patients: throwIfError(patientsResult),
    plans: throwIfError(plansResult),
    alerts: throwIfError(alertsResult),
  };
}

export async function getDoctorProfile(user: User) {
  const result = await requireSupabaseClient().from("profiles").select("display_name, role, active").eq("user_id", user.id).maybeSingle();
  if (result.error) throw new Error(result.error.message);
  return result.data;
}

export async function addPatient(userId: string, patient: {
  name: string; age: number; gender: string; condition: string; phone: string;
  nominee: string; nomineeRelation: string; followUp: string | null;
}) {
  const result = await requireSupabaseClient().from("patients").insert({
    doctor_id: userId,
    name: patient.name.trim(),
    age: patient.age,
    gender: patient.gender,
    condition: patient.condition.trim(),
    phone: patient.phone.trim(),
    nominee: patient.nominee.trim(),
    nominee_relation: patient.nomineeRelation.trim(),
    follow_up: patient.followUp || null,
  });
  if (result.error) throw new Error(result.error.message);
}

function validateDocument(file: File) {
  const supportedTypes = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
  if (!supportedTypes.includes(file.type)) {
    throw new Error("Choose a PDF, JPEG, PNG, or WebP document.");
  }
  if (file.size > 10 * 1024 * 1024) throw new Error("The document must be 10 MB or smaller.");
}

export async function createCarePlanDraft(input: {
  userId: string; patientId: string; notes: string; file: File; medications: Medication[];
}) {
  validateDocument(input.file);
  if (!input.notes.trim()) throw new Error("Add reassessment notes before saving the draft.");
  if (input.medications.length === 0 || input.medications.some((medication) =>
    !medication.name.trim() || !medication.strength.trim() || !medication.directions.trim())) {
    throw new Error("Enter the name, strength, and directions for at least one medication.");
  }
  const client = requireSupabaseClient();
  const safeName = input.file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `${input.userId}/${input.patientId}/${crypto.randomUUID()}-${safeName}`;
  const uploadResult = await client.storage.from("care-plan-documents").upload(path, input.file, {
    contentType: input.file.type,
    upsert: false,
  });
  throwIfError(uploadResult);

  const result = await client.rpc("create_care_plan_draft", {
    p_patient_id: input.patientId,
    p_notes: input.notes.trim(),
    p_source_path: path,
    p_medications: input.medications.map((medication) => ({
      name: medication.name.trim(),
      strength: medication.strength.trim(),
      directions: medication.directions.trim(),
    })),
  });
  if (result.error) {
    const cleanup = await client.storage.from("care-plan-documents").remove([path]);
    if (cleanup.error) {
      throw new Error(`${result.error.message} The uploaded document could not be removed: ${cleanup.error.message}`);
    }
    throw new Error(result.error.message);
  }
  return result.data;
}

export async function actOnCarePlan(planId: string, action: "approve" | "correction" | "reject") {
  const result = await requireSupabaseClient().rpc("act_on_care_plan", { p_plan_id: planId, p_action: action });
  if (result.error) throw new Error(result.error.message);
}

export async function acknowledgeAlert(alertId: string) {
  const result = await requireSupabaseClient().rpc("acknowledge_alert", { p_alert_id: alertId });
  if (result.error) throw new Error(result.error.message);
}

export async function getCarePlanDocumentUrl(path: string) {
  const result = await requireSupabaseClient().storage.from("care-plan-documents").createSignedUrl(path, 60);
  const data = throwIfError(result);
  return data.signedUrl;
}
