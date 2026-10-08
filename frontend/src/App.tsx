import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  Activity, ArrowLeft, ArrowRight, Bell, CalendarDays, Check, CheckCheck, ChevronDown,
  ChevronRight, CircleHelp, ClipboardCheck, ClipboardList, Clock3, Download, FileCheck2,
  FileText, FileUp, LayoutDashboard, LogOut, Menu, MoreHorizontal, Pill, Plus,
  Search, ShieldCheck, Stethoscope, Upload, Users, X,
} from "lucide-react";
import type { User } from "@supabase/supabase-js";
import type { AlertRecord, CarePlanRecord, PatientRecord } from "./services/careSyncData";
import {
  acknowledgeAlert, actOnCarePlan, addPatient, createCarePlanDraft, getDoctorProfile,
  getCarePlanDocumentUrl, loadWorkspace,
} from "./services/careSyncData";
import {
  requestPasswordReset as sendPasswordReset,
  signIn,
  signOut,
  updateRecoveredPassword as saveRecoveredPassword,
} from "./services/auth/authService";
import { supabase, supabaseConfigured } from "./lib/supabase";
import type { Medication } from "./lib/database.types";

type Page = "dashboard" | "patients" | "care-plans" | "alerts" | "follow-ups" | "settings" | "patient" | "review" | "reassessment";
type PatientStatus = "Needs attention" | "Review pending" | "Active plan" | "No plan recorded";
type Patient = PatientRecord & {
  initials: string;
  color: string;
  plan: string;
  status: PatientStatus;
};
type AlertItem = AlertRecord & { patient: string };
type CarePlan = CarePlanRecord & { patient: string };
type PatientForm = {
  name: string; age: string; gender: string; condition: string; phone: string;
  nominee: string; nomineeRelation: string; followUp: string;
};

const nav: { id: Page; label: string; icon: typeof LayoutDashboard }[] = [
  { id: "dashboard", label: "Overview", icon: LayoutDashboard },
  { id: "patients", label: "Patients", icon: Users },
  { id: "care-plans", label: "Care plans", icon: ClipboardList },
  { id: "alerts", label: "Alerts", icon: Bell },
  { id: "follow-ups", label: "Follow-ups", icon: CalendarDays },
];
const patientColors = ["avatar-indigo", "avatar-teal", "avatar-orange", "avatar-pink", "avatar-blue"];
const newPatientForm: PatientForm = {
  name: "", age: "", gender: "", condition: "", phone: "", nominee: "", nomineeRelation: "", followUp: "",
};

function App() {
  const location = useLocation();
  const navigate = useNavigate();
  const page = resolvePage(location.pathname);
  const [user, setUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [authError, setAuthError] = useState("");
  const [passwordRecovery, setPasswordRecovery] = useState(false);
  const [doctorName, setDoctorName] = useState("");
  const [patients, setPatients] = useState<Patient[]>([]);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [plans, setPlans] = useState<CarePlan[]>([]);
  const [dataLoading, setDataLoading] = useState(false);
  const [dataError, setDataError] = useState("");
  const [busy, setBusy] = useState(false);
  const [selectedPatientId, setSelectedPatientId] = useState("");
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("All patients");
  const [toast, setToast] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);
  const [showAddPatient, setShowAddPatient] = useState(false);
  const [patientForm, setPatientForm] = useState<PatientForm>(newPatientForm);
  const [reviewPlanId, setReviewPlanId] = useState("");
  const [note, setNote] = useState("");
  const [document, setDocument] = useState<File | null>(null);
  const [medications, setMedications] = useState<Medication[]>([{ name: "", strength: "", directions: "" }]);

  useEffect(() => {
    if (!supabase) {
      setAuthReady(true);
      return;
    }
    let mounted = true;
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (error) setAuthError(error.message);
      setUser(data.session?.user ?? null);
      setAuthReady(true);
    }).catch((error: unknown) => {
      if (!mounted) return;
      setAuthError(errorMessage(error));
      setAuthReady(true);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      setUser(session?.user ?? null);
      setAuthError("");
      if (event === "PASSWORD_RECOVERY") setPasswordRecovery(true);
      setAuthReady(true);
    });
    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const refreshWorkspace = useCallback(async () => {
    if (!user) return;
    setDataLoading(true);
    setDataError("");
    try {
      const profile = await getDoctorProfile(user);
      if (!profile || profile.role !== "doctor" || !profile.active) {
        throw new Error("This account is not authorized for the CareSync doctor workspace. Ask your administrator to provision doctor access.");
      }
      const workspace = await loadWorkspace();
      const names = new Map(workspace.patients.map((patient) => [patient.id, patient.name]));
      const mappedPlans: CarePlan[] = workspace.plans.map((plan) => ({
        ...plan,
        patient: names.get(plan.patient_id) ?? "Assigned patient",
      }));
      const mappedAlerts: AlertItem[] = workspace.alerts.map((alert) => ({
        ...alert,
        patient: names.get(alert.patient_id) ?? "Assigned patient",
      }));
      const mappedPatients: Patient[] = workspace.patients.map((patient, index) => {
        const patientPlans = mappedPlans.filter((plan) => plan.patient_id === patient.id);
        const currentPlan = patientPlans.find((plan) => plan.status === "active")
          ?? patientPlans.find((plan) => plan.status === "pending_review");
        const hasOpenAlert = mappedAlerts.some((alert) => alert.patient_id === patient.id && alert.status === "open");
        const status: PatientStatus = hasOpenAlert ? "Needs attention"
          : patientPlans.some((plan) => plan.status === "pending_review") ? "Review pending"
          : patientPlans.some((plan) => plan.status === "active") ? "Active plan" : "No plan recorded";
        return {
          ...patient,
          initials: initials(patient.name),
          color: patientColors[index % patientColors.length],
          plan: currentPlan ? `Version ${currentPlan.version} · ${statusLabel(currentPlan.status)}` : "No plan recorded",
          status,
        };
      });
      setDoctorName(profile.display_name);
      setPatients(mappedPatients);
      setPlans(mappedPlans);
      setAlerts(mappedAlerts);
    } catch (error) {
      setDataError(errorMessage(error));
      setPatients([]);
      setPlans([]);
      setAlerts([]);
    } finally {
      setDataLoading(false);
    }
  }, [user]);

  useEffect(() => {
    if (!user) {
      setPatients([]);
      setPlans([]);
      setAlerts([]);
      setDoctorName("");
      return;
    }
    void refreshWorkspace();
  }, [refreshWorkspace, user]);

  const filteredPatients = useMemo(() => patients.filter((patient) => {
    const matchesSearch = `${patient.name} ${patient.id} ${patient.condition}`.toLowerCase().includes(search.toLowerCase());
    const matchesFilter = filter === "All patients" || patient.status === filter;
    return matchesSearch && matchesFilter;
  }), [filter, patients, search]);
  const routePatientId = location.pathname.match(/^\/patients\/([^/]+)/)?.[1];
  const routePlanId = location.pathname.match(/^\/care-plans\/([^/]+)\/review$/)?.[1];
  const activePatientId = routePatientId ?? selectedPatientId;
  const selectedPatient = patients.find((patient) => patient.id === activePatientId);
  const reviewPlan = plans.find((plan) => plan.id === (routePlanId ?? reviewPlanId));
  const pageTitle: Record<Page, string> = {
    dashboard: "Overview", patients: "Patients", "care-plans": "Care plans", alerts: "Alerts & escalations",
    "follow-ups": "Follow-ups", settings: "Settings", patient: selectedPatient?.name ?? "Patient details",
    review: "Care plan review", reassessment: "Patient reassessment",
  };

  const openPage = (next: Page) => {
    const paths: Record<Page, string> = {
      dashboard: "/", patients: "/patients", "care-plans": "/care-plans", alerts: "/alerts",
      "follow-ups": "/follow-ups", settings: "/settings", patient: `/patients/${activePatientId}`,
      review: `/care-plans/${reviewPlanId}/review`, reassessment: `/patients/${activePatientId}/reassessment`,
    };
    navigate(paths[next]);
    setSearch("");
    setSidebarOpen(false);
  };
  const showToast = (message: string) => {
    setToast(message);
    window.setTimeout(() => setToast(""), 3200);
  };
  const runAction = async (action: () => Promise<void>, successMessage: string) => {
    setBusy(true);
    setDataError("");
    try {
      await action();
      await refreshWorkspace();
      showToast(successMessage);
    } catch (error) {
      setDataError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };
  const openPatient = (id: string) => {
    setSelectedPatientId(id);
    navigate(`/patients/${id}`);
    setSearch("");
    setSidebarOpen(false);
  };
  const startReview = (plan: CarePlan) => {
    setReviewPlanId(plan.id);
    setSelectedPatientId(plan.patient_id);
    navigate(`/care-plans/${plan.id}/review`);
    setSidebarOpen(false);
  };
  const handleLogin = async (email: string, password: string) => {
    await signIn(email, password);
    navigate("/");
  };
  const requestPasswordReset = async (email: string) => {
    await sendPasswordReset(email);
  };
  const updateRecoveredPassword = async (password: string) => {
    await saveRecoveredPassword(password);
    setPasswordRecovery(false);
    navigate("/");
  };
  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      setDataError(`Could not sign out: ${errorMessage(error)}`);
      return;
    }
    setShowAddPatient(false);
    navigate("/login");
  };
  const submitPatient = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!user) return;
    setBusy(true);
    setDataError("");
    try {
      await addPatient(user.id, {
        ...patientForm,
        age: Number(patientForm.age),
        followUp: patientForm.followUp || null,
      });
      setShowAddPatient(false);
      setPatientForm(newPatientForm);
      await refreshWorkspace();
      showToast("Patient record saved.");
    } catch (error) {
      setDataError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };
  const submitReassessment = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!user || !selectedPatient || !document) return;
    setBusy(true);
    setDataError("");
    try {
      const planId = await createCarePlanDraft({
        userId: user.id, patientId: selectedPatient.id, notes: note, file: document, medications,
      });
      await refreshWorkspace();
      setNote("");
      setDocument(null);
      setMedications([{ name: "", strength: "", directions: "" }]);
      setReviewPlanId(planId);
      navigate(`/care-plans/${planId}/review`);
      showToast("Care-plan draft saved for doctor review.");
    } catch (error) {
      setDataError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };
  const openDocument = (path: string) => {
    const documentWindow = window.open("about:blank", "_blank");
    if (!documentWindow) {
      setDataError("Allow pop-ups for this site to open the private source document.");
      return;
    }
    documentWindow.opener = null;
    void getCarePlanDocumentUrl(path).then((url) => {
      documentWindow.location.replace(url);
    }).catch((error: unknown) => {
      documentWindow.close();
      setDataError(errorMessage(error));
    });
  };

  if (!authReady) return <div className="login-screen"><span className="brand-mark"><Activity size={21} /></span><p>Restoring secure session…</p></div>;
  if (passwordRecovery) return <PasswordRecovery onSubmit={updateRecoveredPassword} />;
  if (!user) return <Login onLogin={handleLogin} onRequestPasswordReset={requestPasswordReset} initialError={authError} />;

  return (
    <div className="app-shell">
      <aside className={`sidebar ${sidebarOpen ? "sidebar-open" : ""}`}>
        <button className="brand" onClick={() => openPage("dashboard")} aria-label="CareSync home">
          <span className="brand-mark"><Activity size={21} strokeWidth={2.7} /></span>
          <span>care<span className="brand-light">sync</span><small>DOCTOR PORTAL</small></span>
        </button>
        <div className="workspace-label">WORKSPACE</div>
        <nav className="side-nav" aria-label="Main navigation">
          {nav.map(({ id, label, icon: Icon }) => (
            <button key={id} className={`nav-link ${page === id ? "active" : ""}`} onClick={() => openPage(id)}>
              <Icon size={18} strokeWidth={1.9} /><span>{label}</span>
              {id === "alerts" && alerts.filter((item) => item.status === "open").length > 0 && <span className="nav-count">{alerts.filter((item) => item.status === "open").length}</span>}
            </button>
          ))}
        </nav>
        <div className="side-spacer" />
        <div className="sidebar-help"><span className="help-icon"><CircleHelp size={17} /></span><div><b>Secure workspace</b><small>Doctor-managed access</small></div><ShieldCheck size={15} /></div>
        <button className="profile-mini" onClick={() => openPage("settings")}>
          <span className="avatar avatar-doctor">{initials(doctorName || user.email || "D")}</span>
          <span className="profile-copy"><b>{doctorName || "Doctor account"}</b><small>Doctor · {user.email}</small></span><MoreHorizontal size={18} />
        </button>
      </aside>
      {sidebarOpen && <button className="mobile-scrim" aria-label="Close menu" onClick={() => setSidebarOpen(false)} />}
      <main className="main-area">
        <header className="topbar">
          <button className="mobile-menu icon-button" onClick={() => setSidebarOpen(true)} aria-label="Open navigation"><Menu size={20} /></button>
          <div className="breadcrumb"><span>Workspace</span><ChevronRight size={14} /><b>{pageTitle[page]}</b></div>
          <div className="topbar-actions">
            <label className="global-search"><Search size={17} /><input value={search} onChange={(event) => setSearch(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") openPage("patients"); }} placeholder="Search patients..." aria-label="Search patients" /><kbd>↵</kbd></label>
            <button className="icon-button notification-button" aria-label="View alerts" onClick={() => openPage("alerts")}><Bell size={19} /></button>
            <span className="topbar-divider" />
            <div className="profile-menu-wrap">
              <button className="top-profile" aria-expanded={profileMenuOpen} aria-label="Open doctor profile menu" onClick={() => setProfileMenuOpen(!profileMenuOpen)}>
                <span className="avatar avatar-doctor">{initials(doctorName || user.email || "D")}</span>
                <span className="top-profile-copy"><b>{doctorName || user.email?.split("@")[0] || "Doctor"}</b><small>Doctor</small></span>
                <ChevronDown size={14} />
              </button>
              {profileMenuOpen && <div className="profile-dropdown" role="menu">
                <div className="profile-dropdown-heading"><b>{doctorName || "Doctor account"}</b><small>{user.email}</small></div>
                <button role="menuitem" onClick={() => { setProfileMenuOpen(false); openPage("settings"); }}>Account settings</button>
                <button role="menuitem" onClick={() => { setProfileMenuOpen(false); void handleSignOut(); }}><LogOut size={14} /> Sign out</button>
              </div>}
            </div>
          </div>
        </header>
        <div className="page-content">
          {dataError && <div className="data-error" role="alert"><ShieldCheck size={17} /><span>{dataError}</span><button onClick={() => setDataError("")} aria-label="Dismiss error"><X size={15} /></button></div>}
          {dataLoading && <div className="loading-banner" role="status">Loading authorized workspace records…</div>}
          {page === "dashboard" && <Dashboard
            patients={patients}
            alerts={alerts}
            plans={plans}
            doctorName={doctorName}
            dataLoading={dataLoading}
            openPatient={openPatient}
            openPage={openPage}
            startReview={startReview}
            updateAlert={(id) => void runAction(() => acknowledgeAlert(id), "Alert acknowledged.")}
            onStartDraft={() => {
              openPage("patients");
              showToast("Choose a patient to start a doctor-entered reassessment. AI extraction is not connected.");
            }}
          />}
          {page === "patients" && <PatientsPage patients={filteredPatients} allCount={patients.length} filter={filter} setFilter={setFilter} openPatient={openPatient} search={search} onAdd={() => setShowAddPatient(true)} />}
          {page === "patient" && (selectedPatient
            ? <PatientPage patient={selectedPatient} plans={plans.filter((plan) => plan.patient_id === selectedPatient.id)} alerts={alerts.filter((alert) => alert.patient_id === selectedPatient.id)} back={() => openPage("patients")} openReassessment={() => { setNote(""); setDocument(null); setMedications([{ name: "", strength: "", directions: "" }]); openPage("reassessment"); }} startReview={startReview} />
            : <EmptyState title="Patient record unavailable" detail="The record may not exist or may not be assigned to your account." />)}
          {page === "care-plans" && <CarePlansPage plans={plans} startReview={startReview} />}
          {page === "review" && (reviewPlan
            ? <ReviewPage plan={reviewPlan} patient={patients.find((item) => item.id === reviewPlan.patient_id)} onAction={(action) => void runAction(async () => { await actOnCarePlan(reviewPlan.id, action); navigate("/care-plans"); }, action === "approve" ? "Care plan approved." : action === "correction" ? "Correction request recorded." : "Care plan rejected.")} onOpenDocument={() => openDocument(reviewPlan.source_path)} busy={busy} back={() => openPage("care-plans")} />
            : <EmptyState title="Care plan unavailable" detail="The plan may not exist or may not be assigned to your account." />)}
          {page === "alerts" && <AlertsPage alerts={alerts} openPatient={openPatient} updateAlert={(id) => void runAction(() => acknowledgeAlert(id), "Alert acknowledged.")} />}
          {page === "follow-ups" && <FollowUpsPage patients={patients} openPatient={openPatient} startReassessment={(id) => { setSelectedPatientId(id); setNote(""); setDocument(null); setMedications([{ name: "", strength: "", directions: "" }]); navigate(`/patients/${id}/reassessment`); }} />}
          {page === "reassessment" && (selectedPatient
            ? <ReassessmentPage patient={selectedPatient} note={note} setNote={setNote} document={document} setDocument={setDocument} medications={medications} setMedications={setMedications} onSubmit={submitReassessment} busy={busy} back={() => openPage("patient")} />
            : <EmptyState title="No patient selected" detail="Select an assigned patient before starting a reassessment." />)}
          {page === "settings" && <SettingsPage user={user} doctorName={doctorName} onLogout={() => void handleSignOut()} />}
        </div>
        <footer className="footer"><span>© CareSync Health</span><span><ShieldCheck size={13} /> Authenticated clinical workspace <i /> Private doctor-scoped records</span></footer>
      </main>
      {showAddPatient && <AddPatientForm form={patientForm} setForm={setPatientForm} onSubmit={(event) => void submitPatient(event)} onClose={() => setShowAddPatient(false)} busy={busy} />}
      {toast && <div className="toast" role="status"><span className="toast-check"><Check size={15} /></span>{toast}<button onClick={() => setToast("")} aria-label="Dismiss notification"><X size={15} /></button></div>}
    </div>
  );
}

function resolvePage(path: string): Page {
  if (path.startsWith("/patients/") && path.endsWith("/reassessment")) return "reassessment";
  if (path.startsWith("/patients/")) return "patient";
  if (path.startsWith("/care-plans/") && path.endsWith("/review")) return "review";
  if (path === "/patients") return "patients";
  if (path === "/care-plans") return "care-plans";
  if (path === "/alerts") return "alerts";
  if (path === "/follow-ups") return "follow-ups";
  if (path === "/settings") return "settings";
  return "dashboard";
}

function initials(value: string) {
  return value.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase() ?? "").join("") || "D";
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "An unexpected error occurred. Please try again.";
}

function formatDate(value: string | null, fallback = "Not recorded") {
  if (!value) return fallback;
  const date = new Date(`${value.slice(0, 10)}T00:00:00`);
  return Number.isNaN(date.getTime()) ? fallback : date.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

function localDateValue(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function timeAgo(value: string) {
  const elapsed = Math.max(0, Date.now() - new Date(value).getTime());
  const minutes = Math.floor(elapsed / 60000);
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function statusLabel(status: string) {
  return status === "pending_review" ? "Review pending"
    : status === "correction_requested" ? "Correction requested"
    : status.charAt(0).toUpperCase() + status.slice(1);
}

function PageHeading({ eyebrow, title, subtitle, action }: { eyebrow?: string; title: ReactNode; subtitle?: string; action?: ReactNode }) {
  return <div className="page-heading"><div>{eyebrow && <div className="eyebrow">{eyebrow}</div>}<h1>{title}</h1>{subtitle && <p>{subtitle}</p>}</div>{action && <div className="heading-action">{action}</div>}</div>;
}

function StatusBadge({ status }: { status: string }) {
  const style = status === "Active" || status === "Resolved" || status === "Active plan" ? "green"
    : status === "Needs attention" || status === "Urgent" || status === "Open" ? "red"
    : status === "Review pending" || status === "Warning" || status === "Acknowledged" || status === "Correction requested" ? "amber" : "blue";
  return <span className={`status-badge ${style}`}><i />{status}</span>;
}

function Avatar({ patient, small = false }: { patient: Patient; small?: boolean }) {
  return <span className={`avatar patient-avatar ${patient.color} ${small ? "avatar-small" : ""}`}>{patient.initials}</span>;
}

function EmptyState({ title, detail }: { title: string; detail: string }) {
  return <div className="empty-state"><span className="empty-icon"><FileText size={20} /></span><b>{title}</b><p>{detail}</p></div>;
}

function Dashboard({ patients, alerts, plans, doctorName, dataLoading, openPatient, openPage, startReview, updateAlert, onStartDraft }: {
  patients: Patient[]; alerts: AlertItem[]; plans: CarePlan[]; doctorName: string; dataLoading: boolean;
  openPatient: (id: string) => void; openPage: (page: Page) => void;
  startReview: (plan: CarePlan) => void; updateAlert: (id: string) => void; onStartDraft: () => void;
}) {
  return <ClinicalDashboard patients={patients} alerts={alerts} plans={plans} doctorName={doctorName} dataLoading={dataLoading} openPatient={openPatient} openPage={openPage} startReview={startReview} updateAlert={updateAlert} onStartDraft={onStartDraft} />;
}

type AttentionRow = {
  id: string; name: string; initials: string; condition: string; lastVisit: string;
  planStatus: string; alert: string; color: string; patient?: Patient;
  alertRecord?: AlertItem;
};
type FollowUpRow = { id: string; name: string; time: string; reason: string; status: string; patient?: Patient };

function ClinicalDashboard({ patients, alerts, plans, doctorName, dataLoading, openPatient, openPage, startReview, updateAlert, onStartDraft }: {
  patients: Patient[]; alerts: AlertItem[]; plans: CarePlan[]; doctorName: string; dataLoading: boolean;
  openPatient: (id: string) => void; openPage: (page: Page) => void;
  startReview: (plan: CarePlan) => void; updateAlert: (id: string) => void; onStartDraft: () => void;
}) {
  const [selectedDocument, setSelectedDocument] = useState<File | null>(null);
  const openAlerts = alerts.filter((alert) => alert.status === "open");
  const pendingPlans = plans.filter((plan) => plan.status === "pending_review");
  const today = localDateValue(new Date());
  const liveAttention: AttentionRow[] = patients.filter((patient) => {
    const patientAlerts = openAlerts.filter((alert) => alert.patient_id === patient.id);
    return patientAlerts.length > 0 || patient.status === "Review pending" || patient.follow_up === today;
  }).slice(0, 5).map((patient) => {
    const patientAlert = openAlerts.find((alert) => alert.patient_id === patient.id);
    const planStatus = patient.status === "Review pending" ? "Review Required"
      : patient.status === "Active plan" ? "Active" : "No plan";
    return {
      id: patient.id,
      name: patient.name,
      initials: patient.initials,
      condition: patient.condition,
      lastVisit: "Not recorded",
      planStatus,
      alert: patientAlert?.reason ?? (patient.follow_up === today ? "Follow-up due" : "None"),
      color: patient.color,
      patient,
      alertRecord: patientAlert,
    };
  });
  const attentionRows = liveAttention;
  const followUps: FollowUpRow[] = patients
    .filter((patient) => patient.follow_up === today)
    .map((patient) => ({
      id: patient.id, name: patient.name, time: "Time not recorded",
      reason: "Scheduled follow-up", status: "Scheduled", patient,
    }));
  const greetingName = doctorName.trim() ? `Dr. ${doctorName.trim()}` : "Doctor";
  const greeting = new Date().getHours() < 12 ? "Good morning" : new Date().getHours() < 17 ? "Good afternoon" : "Good evening";
  const carePlanCount = plans.length;
  const patientsCount = patients.length;
  const pendingCount = pendingPlans.length;
  const followUpCount = followUps.length;
  const recentPlans: { patient: string; generated: string; status: string; id: string; plan?: CarePlan }[] = plans.slice(0, 5).map((plan) => ({
    patient: plan.patient,
    generated: timeAgo(plan.created_at),
    status: plan.status === "active" ? "Approved" : statusLabel(plan.status),
    id: plan.id,
    plan,
  }));
  const fileInputId = "dashboard-discharge-upload";
  return <>
    <section className="overview-welcome">
      <div><div className="eyebrow">CLINICAL OVERVIEW</div><h1>{greeting}, {greetingName}</h1><p>Here's your patient care overview for today.</p></div>
      <div className="overview-date"><CalendarDays size={16} /><span>{new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}</span></div>
    </section>
    <section className="clinical-stat-grid" aria-label="Clinical summary">
      <ClinicalStat title="Total Patients" value={patientsCount} note="In your workspace" icon={<Users size={19} />} tone="navy" />
      <ClinicalStat title="Care Plans" value={carePlanCount} note="Plans in your workspace" icon={<ClipboardCheck size={19} />} tone="blue" />
      <ClinicalStat title="Pending Reviews" value={pendingCount} note="Require your review" icon={<FileCheck2 size={19} />} tone="amber" />
      <ClinicalStat title="Follow-ups Today" value={followUpCount} note="Scheduled today" icon={<CalendarDays size={19} />} tone="teal" />
    </section>
    <section className="overview-primary-grid">
      <div className="card clinical-table-card">
        <div className="overview-section-heading"><div><span className="section-kicker">CARE COORDINATION</span><h2>Patients needing attention</h2><p>Prioritize follow-ups and care-plan reviews.</p></div><button className="button button-secondary" onClick={() => openPage("patients")}>View all patients <ArrowRight size={15} /></button></div>
        <div className="clinical-table-scroll"><table className="clinical-table"><thead><tr><th>Patient</th><th>Condition</th><th>Last visit</th><th>Care plan</th><th>Alert</th><th><span className="sr-only">Action</span></th></tr></thead><tbody>
          {attentionRows.map((row) => <tr key={row.id}>
            <td><button className="clinical-patient-cell" onClick={() => row.patient ? openPatient(row.patient.id) : openPage("patients")}><span className={`avatar patient-avatar ${row.color} avatar-small`}>{row.initials}</span><span><b>{row.name}</b><small>Assigned patient</small></span></button></td>
            <td>{row.condition}</td><td>{row.lastVisit}</td><td><span className={`clinical-status ${statusTone(row.planStatus)}`}>{row.planStatus}</span></td>
            <td><span className={`clinical-alert ${row.alert === "None" ? "is-clear" : ""}`}><i />{row.alert}</span></td>
            <td className="clinical-row-actions">
              {row.alertRecord && <button className="clinical-ack-action" onClick={() => updateAlert(row.alertRecord!.id)}>Acknowledge</button>}
              <button className="clinical-row-action" aria-label={`Open ${row.name}`} onClick={() => row.patient ? openPatient(row.patient.id) : openPage("patients")}><ArrowRight size={16} /></button>
            </td>
          </tr>)}
          {!dataLoading && attentionRows.length === 0 && <tr><td colSpan={6}><EmptyState title="No patients needing attention" detail="Patients with alerts or reviews will appear here." /></td></tr>}
        </tbody></table></div>
      </div>
      <div className="card ai-assistant-card">
        <div className="ai-card-header"><span className="ai-assistant-icon"><Stethoscope size={19} /></span><span className="ai-review-label"><ShieldCheck size={13} /> AI Generated — Doctor Review Required</span></div>
        <h2>AI Care Plan Assistant</h2><p className="ai-assistant-subtitle">Turn discharge summaries into personalized care plans.</p>
        <label className={`ai-upload-zone ${selectedDocument ? "has-file" : ""}`} htmlFor="dashboard-discharge-upload" onDragOver={(event) => event.preventDefault()} onDrop={(event) => {
          event.preventDefault();
          const file = event.dataTransfer.files[0];
          if (file && /\.(pdf|docx)$/i.test(file.name)) setSelectedDocument(file);
        }}>
          <input id={fileInputId} type="file" accept=".pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document" onChange={(event) => setSelectedDocument(event.target.files?.[0] ?? null)} />
          <span className="ai-upload-icon">{selectedDocument ? <FileText size={22} /> : <FileUp size={22} />}</span>
          <b>{selectedDocument ? selectedDocument.name : "Upload discharge summary"}</b>
          <small>{selectedDocument ? "Selected locally; not uploaded" : "Drag a file here, or browse to upload"}</small>
          <span className="ai-format-note">Supported formats: PDF, DOCX</span>
          <span className="button button-secondary"><Upload size={14} /> Choose document</span>
        </label>
        <button className="button button-primary ai-generate-button" disabled={!selectedDocument || dataLoading} onClick={onStartDraft}>Generate Care Plan <ArrowRight size={15} /></button>
        <p className="ai-safety-copy">CareSync can extract medicines, dosage, follow-up instructions and warning signs from discharge summaries. Review all AI-generated content before sending it to the patient.</p>
        <p className="ai-connection-note">AI extraction is not connected in this build. This document stays in your browser and is not uploaded.</p>
      </div>
    </section>
    <section className="overview-secondary-grid">
      <div className="card overview-list-card">
        <div className="overview-section-heading compact"><div><span className="section-kicker">LATEST ACTIVITY</span><h2>Recent Care Plans</h2></div><button className="text-button" onClick={() => openPage("care-plans")}>View all <ArrowRight size={14} /></button></div>
        <div className="recent-plan-list">
          {recentPlans.map((item) => <div className="recent-plan-row" key={item.id}>
            <span className="recent-plan-icon"><FileText size={17} /></span><span className="recent-plan-patient"><b>{item.patient}</b><small>{item.generated}</small></span>
            <span className={`clinical-status ${statusTone(item.status)}`}>{item.status}</span>
            <span className="doctor-review-mark">{item.status === "Approved" ? <><Check size={13} /> Doctor Approved</> : <><Clock3 size={13} /> Doctor review</>}</span>
            {(item.plan && item.status === "Review pending")
              ? <button className="clinical-row-action" aria-label={`Review care plan for ${item.patient}`} onClick={() => { if (item.plan) startReview(item.plan); }}><ArrowRight size={16} /></button>
              : <button className="clinical-row-action" aria-label={`View care plans for ${item.patient}`} onClick={() => openPage("care-plans")}><ArrowRight size={16} /></button>}
          </div>)}
          {recentPlans.length === 0 && <EmptyState title="No care plans yet" detail="Care plans will appear here when added to your workspace." />}
        </div>
      </div>
      <div className="card overview-list-card follow-up-list-card">
        <div className="overview-section-heading compact"><div><span className="section-kicker">TODAY'S SCHEDULE</span><h2>Today's Follow-ups</h2></div><button className="text-button" onClick={() => openPage("follow-ups")}>View schedule <ArrowRight size={14} /></button></div>
        <div className="today-followup-list">
          {followUps.slice(0, 4).map((item) => <div className="today-followup-row" key={item.id}>
            <span className="followup-time-block"><b>{item.time}</b><i /></span>
            <span className="followup-patient-copy"><b>{item.name}</b><small>{item.reason}</small></span>
            <span className={`clinical-status ${statusTone(item.status)}`}>{item.status}</span>
            <button className="clinical-row-action" aria-label={`Open ${item.name} follow-up`} onClick={() => item.patient ? openPatient(item.patient.id) : openPage("patients")}><ArrowRight size={16} /></button>
          </div>)}
          {followUps.length === 0 && <EmptyState title="No follow-ups today" detail="Today's scheduled follow-ups will appear here." />}
        </div>
      </div>
    </section>
  </>;
}

function statusTone(status: string) {
  if (status === "Approved" || status === "Active" || status === "Confirmed" || status === "Arrived") return "status-good";
  if (status === "Review Required" || status === "Pending Review" || status === "Upcoming" || status === "Draft" || status === "Follow-up due") return "status-pending";
  if (status === "Alert" || status === "Missed check-in" || status === "Medication review") return "status-alert";
  return "status-neutral";
}

function ClinicalStat({ title, value, note, icon, tone }: { title: string; value: number; note: string; icon: ReactNode; tone: string }) {
  return <div className="card clinical-stat-card"><span className={`clinical-stat-icon ${tone}`}>{icon}</span><span className="clinical-stat-content"><span className="clinical-stat-title">{title}</span><b>{value.toLocaleString()}</b><small><i />{note}</small></span></div>;
}

function PatientsPage({ patients, allCount, filter, setFilter, openPatient, search, onAdd }: {
  patients: Patient[]; allCount: number; filter: string; setFilter: (filter: string) => void;
  openPatient: (id: string) => void; search: string; onAdd: () => void;
}) {
  const filters = ["All patients", "Needs attention", "Active plan", "Review pending"];
  return <>
    <PageHeading eyebrow="CARE MANAGEMENT" title="Patients" subtitle="View and manage patient records assigned to your account." action={<button className="button button-primary" onClick={onAdd}><Plus size={16} /> Add patient</button>} />
    <div className="card table-card"><div className="table-toolbar"><div className="table-tabs">{filters.map((item) => <button key={item} onClick={() => setFilter(item)} className={filter === item ? "selected" : ""}>{item}{item === "All patients" && <span className="tab-count">{allCount}</span>}</button>)}</div><div className="table-tools"><label className="table-search"><Search size={15} /><input value={search} readOnly placeholder="Search patients" aria-label="Patient search (use top search)" /></label></div></div>
      {patients.length ? <div className="table-wrap"><table><thead><tr><th>Patient</th><th>Condition</th><th>Care plan</th><th>Adherence</th><th>Last activity</th><th>Follow-up</th><th>Status</th><th /></tr></thead><tbody>{patients.map((patient) => <tr key={patient.id} onClick={() => openPatient(patient.id)} tabIndex={0} onKeyDown={(event) => { if (event.key === "Enter") openPatient(patient.id); }}>
        <td><div className="table-patient"><Avatar patient={patient} small /><span><b>{patient.name}</b><small>{patient.id.slice(0, 8)} · {patient.age} yrs, {patient.gender}</small></span></div></td><td className="condition-cell">{patient.condition}</td><td>{patient.plan}</td><td><span className={`adherence-value ${(patient.adherence_percent ?? 100) < 70 ? "low" : ""}`}>{patient.adherence_percent === null ? "—" : `${patient.adherence_percent}%`}</span>{patient.adherence_percent !== null && <div className="mini-progress"><i style={{ width: `${patient.adherence_percent}%` }} /></div>}</td><td>{timeAgo(patient.updated_at)}</td><td>{formatDate(patient.follow_up)}</td><td><StatusBadge status={patient.status} /></td><td><button className="icon-button row-open" aria-label={`Open ${patient.name}`} onClick={(event) => { event.stopPropagation(); openPatient(patient.id); }}><ArrowRight size={16} /></button></td>
      </tr>)}</tbody></table></div> : <EmptyState title={search ? "No matching patient records" : "No patient records"} detail={search ? "Try a different search." : "Add an authorized patient record to begin."} />}
      <div className="table-footer"><span>Showing <b>{patients.length}</b> of <b>{filter === "All patients" && !search ? allCount : patients.length}</b> patients</span></div>
    </div>
  </>;
}

function PatientPage({ patient, plans, alerts, back, openReassessment, startReview }: {
  patient: Patient; plans: CarePlan[]; alerts: AlertItem[]; back: () => void;
  openReassessment: () => void; startReview: (plan: CarePlan) => void;
}) {
  return <>
    <button className="back-link" onClick={back}><ArrowLeft size={15} /> Back to patients</button>
    <div className="patient-profile-header card"><Avatar patient={patient} /><div className="patient-profile-copy"><div className="profile-title"><h1>{patient.name}</h1><StatusBadge status={patient.status} /></div><p>{patient.id.slice(0, 8)} <i /> {patient.age} years old <i /> {patient.gender}</p><div className="profile-condition"><Stethoscope size={14} />{patient.condition}</div></div><div className="patient-actions"><button className="button button-secondary" onClick={openReassessment}><FileText size={15} /> Add reassessment</button></div></div>
    <div className="patient-detail-grid">
      <div className="card detail-card"><div className="card-heading"><div><h2>Patient information</h2><p>Details entered for this patient</p></div></div>
        <div className="settings-info"><span>Phone</span><b>{patient.phone}</b></div><div className="settings-info"><span>Condition</span><b>{patient.condition}</b></div><div className="settings-info"><span>Follow-up</span><b>{formatDate(patient.follow_up)}</b></div><div className="settings-info"><span>Emergency contact</span><b>{patient.nominee || "Not recorded"}</b></div><div className="settings-info"><span>Contact relationship</span><b>{patient.nominee_relation || "Not recorded"}</b></div>
      </div>
      <div className="card detail-card"><div className="card-heading"><div><h2>Care plans</h2><p>Version history for this patient</p></div></div>
        {plans.length ? <div className="plan-list">{plans.map((plan) => <div className="plan-row" key={plan.id}><span className="file-icon plan-file"><FileText size={18} /></span><div className="plan-main"><b>Version {plan.version}</b><small>{timeAgo(plan.created_at)}</small></div><StatusBadge status={statusLabel(plan.status)} />{plan.status === "pending_review" && <button className="button button-primary" onClick={() => startReview(plan)}>Review</button>}</div>)}</div> : <EmptyState title="No care plans" detail="Reassess this patient to record a new care-plan draft." />}
      </div>
      <div className="card detail-card"><div className="card-heading"><div><h2>Alerts</h2><p>Alerts recorded for this patient</p></div></div>
        {alerts.length ? alerts.map((alert) => <div className="alert-row detail-alert" key={alert.id}><span className={`alert-icon ${alert.severity}`}><Bell size={15} /></span><span className="alert-copy"><b>{alert.reason}</b><span>{alert.detail || "No additional detail"}</span><small>{timeAgo(alert.created_at)} · {statusLabel(alert.status)}</small></span></div>) : <EmptyState title="No alerts" detail="No alert records are associated with this patient." />}
      </div>
    </div>
  </>;
}

function CarePlansPage({ plans, startReview }: { plans: CarePlan[]; startReview: (plan: CarePlan) => void }) {
  const [filter, setFilter] = useState("All plans");
  const options = ["All plans", "Review pending", "Active", "Correction requested", "Rejected", "Superseded"];
  const shownPlans = plans.filter((plan) => filter === "All plans" || statusLabel(plan.status) === filter);
  return <>
    <PageHeading eyebrow="CLINICAL WORKFLOW" title="Care plans" subtitle="Review care-plan drafts and follow their version history." action={<span className="ai-disclaimer"><ShieldCheck size={14} /> Doctor verified</span>} />
    <div className="care-plan-summary"><div className="card summary-mini"><span className="summary-icon amber"><Clock3 size={17} /></span><div><b>{plans.filter((plan) => plan.status === "pending_review").length}</b><small>Awaiting review</small></div></div><div className="card summary-mini"><span className="summary-icon green"><CheckCheck size={17} /></span><div><b>{plans.filter((plan) => plan.status === "active").length}</b><small>Active plans</small></div></div><div className="card summary-mini"><span className="summary-icon blue"><FileCheck2 size={17} /></span><div><b>{plans.length}</b><small>Total versions</small></div></div></div>
    <div className="card plan-list-card"><div className="card-heading"><div><h2>All care plans</h2><p>Each draft requires your clinical verification before activation</p></div><select className="select-button native-select" value={filter} onChange={(event) => setFilter(event.target.value)} aria-label="Filter care plans">{options.map((option) => <option key={option}>{option}</option>)}</select></div>
      <div className="plan-list">{shownPlans.map((plan) => <div className="plan-row" key={plan.id}><span className="file-icon plan-file"><FileText size={18} /></span><div className="plan-main"><b>{plan.patient}</b><small>{plan.id.slice(0, 8)} · Version {plan.version} · {timeAgo(plan.created_at)}</small></div><span className="plan-document"><FileText size={14} /> {plan.source_path.split("/").pop()}</span><StatusBadge status={statusLabel(plan.status)} /><button className={plan.status === "pending_review" ? "button button-primary plan-review-button" : "button button-secondary plan-review-button"} disabled={plan.status !== "pending_review"} onClick={() => startReview(plan)}>{plan.status === "pending_review" ? "Review plan" : "Reviewed"}<ArrowRight size={14} /></button></div>)}
      {shownPlans.length === 0 && <EmptyState title="No care plans here" detail={plans.length ? "Try changing the status filter." : "Care-plan drafts will appear here after reassessment."} />}
      </div><p className="clinical-note"><ShieldCheck size={15} /> Verify medication details against the uploaded source document before approval.</p>
    </div>
  </>;
}

function ReviewPage({ plan, patient, onAction, onOpenDocument, busy, back }: {
  plan: CarePlan; patient?: Patient; onAction: (action: "approve" | "correction" | "reject") => void;
  onOpenDocument: () => void; busy: boolean; back: () => void;
}) {
  const [checked, setChecked] = useState(false);
  const canApprove = plan.status === "pending_review" && checked && plan.medications.length > 0;
  return <>
    <button className="back-link" onClick={back}><ArrowLeft size={15} /> Back to care plans</button>
    <PageHeading eyebrow={`DOCTOR VERIFICATION · VERSION ${plan.version}`} title={`Review ${patient?.name ?? "patient"}’s care plan`} subtitle={`${patient?.id.slice(0, 8) ?? plan.patient_id.slice(0, 8)} · Submitted ${timeAgo(plan.created_at)}`} action={<StatusBadge status={statusLabel(plan.status)} />} />
    <div className="review-warning"><ShieldCheck size={16} /><span><b>Doctor review required</b><small>This draft contains user-entered information and an uploaded source document. Verify it independently; no AI extraction or clinical recommendation is implied.</small></span><ShieldCheck size={18} /></div>
    <div className="review-columns">
      <div className="card document-preview"><div className="card-heading"><div><h2>Uploaded source document</h2><p>{plan.source_path.split("/").pop()}</p></div><button className="icon-button" aria-label="Open source document" onClick={onOpenDocument}><Download size={16} /></button></div>
        <div className="paper-document reassessment-paper"><span className="ai-chip">PRIVATE DOCUMENT</span><p className="paper-patient">Patient: <b>{patient?.name ?? "Assigned patient"}</b></p><p className="paper-label">REASSESSMENT NOTES</p><p className="paper-script">{plan.notes}</p><div className="paper-note">Use the document button above to open the uploaded source securely.</div></div>
        <div className="document-meta"><span><ShieldCheck size={14} /> Private storage</span><span><FileText size={14} /> Signed link expires in 60 seconds</span></div>
      </div>
      <div className="card extraction-card"><div className="card-heading"><div><h2>Entered medication details</h2><p>Verify every field against the source document</p></div><span className="ai-chip"><Pill size={13} /> Doctor-entered</span></div>
        {patient && <div className="extraction-patient"><Avatar patient={patient} small /><span><b>{patient.name}</b><small>{patient.id.slice(0, 8)} · {patient.age} yrs, {patient.gender}</small></span><span className="confidence-label">Version <b>{plan.version}</b></span></div>}
        <div className="extracted-medicine-list">{plan.medications.map((medication, index) => <div className="extracted-med" key={`${medication.name}-${index}`}><span className="pill-icon"><Pill size={16} /></span><div><b>{medication.name}</b><small>{medication.strength}</small></div><span className="extracted-schedule">{medication.directions}</span></div>)}
          {plan.medications.length === 0 && <EmptyState title="No medication entries" detail="This draft cannot be approved without medication details." />}
        </div>
        <div className="verify-check"><label><input type="checkbox" checked={checked} onChange={(event) => setChecked(event.target.checked)} /> I reviewed the uploaded source document and verified each medication detail.</label></div>
        <div className="review-actions"><button className="button button-secondary reject-button" disabled={busy || plan.status !== "pending_review"} onClick={() => onAction("reject")}><X size={15} /> Reject</button><button className="button button-secondary" disabled={busy || plan.status !== "pending_review"} onClick={() => onAction("correction")}><FileText size={15} /> Request correction</button><button className="button button-primary" disabled={busy || !canApprove} onClick={() => onAction("approve")}><Check size={16} /> Approve care plan</button></div>
        <p className="review-action-note"><ShieldCheck size={13} /> Approval is recorded in the audit log; the previous active version is preserved.</p>
      </div>
    </div>
  </>;
}

function AlertsPage({ alerts, openPatient, updateAlert }: { alerts: AlertItem[]; openPatient: (id: string) => void; updateAlert: (id: string) => void }) {
  const [filter, setFilter] = useState("All alerts");
  const shownAlerts = alerts.filter((alert) => filter === "All alerts" || statusLabel(alert.status) === filter);
  return <>
    <PageHeading eyebrow="CARE MANAGEMENT" title="Alerts & escalations" subtitle="Review alerts recorded for patients assigned to you." />
    <div className="card alert-page-card"><div className="card-heading"><div><h2>Patient alerts</h2><p>{alerts.filter((alert) => alert.status === "open").length} open alerts</p></div><select className="select-button native-select" value={filter} onChange={(event) => setFilter(event.target.value)} aria-label="Filter alerts"><option>All alerts</option><option>Open</option><option>Acknowledged</option><option>Resolved</option></select></div>
      <div className="alert-list">{shownAlerts.map((alert) => <div className="alert-row page-alert-row" key={alert.id}><span className={`alert-icon ${alert.severity}`}><Bell size={15} /></span><button className="alert-copy" onClick={() => openPatient(alert.patient_id)}><b>{alert.patient}</b><span>{alert.reason}</span><small>{alert.detail || "No additional detail"} · {timeAgo(alert.created_at)}</small></button><StatusBadge status={statusLabel(alert.status)} />{alert.status === "open" && <button className="button button-secondary" onClick={() => updateAlert(alert.id)}>Acknowledge</button>}</div>)}
        {shownAlerts.length === 0 && <EmptyState title="No alerts" detail={alerts.length ? "No alerts match this filter." : "Alerts will appear here when recorded for assigned patients."} />}
      </div>
    </div>
  </>;
}

function FollowUpsPage({ patients, openPatient, startReassessment }: {
  patients: Patient[]; openPatient: (id: string) => void; startReassessment: (id: string) => void;
}) {
  const scheduled = [...patients].filter((patient) => patient.follow_up).sort((a, b) => (a.follow_up ?? "").localeCompare(b.follow_up ?? ""));
  return <>
    <PageHeading eyebrow="CARE MANAGEMENT" title="Follow-ups" subtitle="Upcoming dates recorded on patient records." />
    <div className="card follow-up-card">{scheduled.map((patient) => <div className="follow-up-row" key={patient.id}><span className="follow-date"><CalendarDays size={18} /><b>{formatDate(patient.follow_up)}</b></span><Avatar patient={patient} small /><button className="alert-copy" onClick={() => openPatient(patient.id)}><b>{patient.name}</b><span>{patient.condition}</span><small>{patient.phone}</small></button><StatusBadge status={patient.status} /><button className="button button-secondary" onClick={() => startReassessment(patient.id)}><FileText size={14} /> Reassess</button></div>)}
      {scheduled.length === 0 && <EmptyState title="No follow-ups scheduled" detail="Follow-up dates entered on patient records will appear here." />}
    </div>
  </>;
}

function ReassessmentPage({ patient, note, setNote, document, setDocument, medications, setMedications, onSubmit, busy, back }: {
  patient: Patient; note: string; setNote: (note: string) => void; document: File | null; setDocument: (file: File | null) => void;
  medications: Medication[]; setMedications: (medications: Medication[]) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void; busy: boolean; back: () => void;
}) {
  const updateMedication = (index: number, field: keyof Medication, value: string) => {
    setMedications(medications.map((medication, medicationIndex) => medicationIndex === index ? { ...medication, [field]: value } : medication));
  };
  return <>
    <button className="back-link" onClick={back}><ArrowLeft size={15} /> Back to patient</button>
    <PageHeading eyebrow="CLINICAL WORKFLOW" title={`Reassess ${patient.name}`} subtitle="Enter the clinician's notes and medication details from the source document." />
    <form className="card reassessment-form" onSubmit={onSubmit}>
      <div className="form-section"><h2>Source document</h2><p>Upload the patient-provided prescription or care-plan document for secure review.</p><label className="form-field">Prescription or care-plan file<input type="file" accept=".pdf,.jpg,.jpeg,.png,.webp,application/pdf,image/jpeg,image/png,image/webp" required onChange={(event) => setDocument(event.target.files?.[0] ?? null)} /></label><small>PDF, JPEG, PNG or WebP · Up to 10 MB · Stored privately</small>{document && <span className="selected-file"><FileText size={15} /> {document.name}</span>}</div>
      <div className="form-section"><h2>Reassessment notes</h2><label className="form-field">Clinical notes<textarea value={note} onChange={(event) => setNote(event.target.value)} required maxLength={10000} rows={5} placeholder="Enter the reassessment notes to retain with this draft." /></label></div>
      <div className="form-section"><div className="form-section-heading"><div><h2>Medication details</h2><p>Enter details from the source document. No medication is inferred automatically.</p></div><button type="button" className="button button-secondary" onClick={() => setMedications([...medications, { name: "", strength: "", directions: "" }])}><Plus size={15} /> Add medicine</button></div>
        {medications.map((medication, index) => <div className="medication-input-row" key={index}><label className="form-field">Medicine<input required value={medication.name} onChange={(event) => updateMedication(index, "name", event.target.value)} /></label><label className="form-field">Strength<input required value={medication.strength} onChange={(event) => updateMedication(index, "strength", event.target.value)} placeholder="As written" /></label><label className="form-field">Directions<input required value={medication.directions} onChange={(event) => updateMedication(index, "directions", event.target.value)} placeholder="Dose and schedule as written" /></label>{medications.length > 1 && <button type="button" className="icon-button" aria-label={`Remove medicine ${index + 1}`} onClick={() => setMedications(medications.filter((_, row) => row !== index))}><X size={15} /></button>}</div>)}
      </div>
      <div className="form-actions"><button type="button" className="button button-secondary" onClick={back}>Cancel</button><button type="submit" className="button button-primary" disabled={busy}>{busy ? "Saving…" : "Save draft for review"} <ArrowRight size={15} /></button></div>
    </form>
  </>;
}

function AddPatientForm({ form, setForm, onSubmit, onClose, busy }: {
  form: PatientForm; setForm: (form: PatientForm) => void; onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onClose: () => void; busy: boolean;
}) {
  const update = (field: keyof PatientForm, value: string) => setForm({ ...form, [field]: value });
  return <div className="modal-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <form className="card modal-card" onSubmit={onSubmit}>
      <div className="card-heading"><div><div className="eyebrow">CARE MANAGEMENT</div><h2>Add patient record</h2><p>Enter the details to save to your authorized workspace.</p></div><button type="button" className="icon-button" aria-label="Close form" onClick={onClose}><X size={18} /></button></div>
      <div className="patient-form-grid">
        <label className="form-field">Patient name<input required maxLength={160} value={form.name} onChange={(event) => update("name", event.target.value)} /></label>
        <label className="form-field">Age<input required type="number" min="0" max="125" value={form.age} onChange={(event) => update("age", event.target.value)} /></label>
        <label className="form-field">Gender<input required maxLength={80} value={form.gender} onChange={(event) => update("gender", event.target.value)} /></label>
        <label className="form-field">Phone<input required type="tel" maxLength={40} value={form.phone} onChange={(event) => update("phone", event.target.value)} /></label>
        <label className="form-field full-field">Condition<input required maxLength={500} value={form.condition} onChange={(event) => update("condition", event.target.value)} /></label>
        <label className="form-field">Emergency contact<input value={form.nominee} maxLength={160} onChange={(event) => update("nominee", event.target.value)} /></label>
        <label className="form-field">Relationship<input value={form.nomineeRelation} maxLength={80} onChange={(event) => update("nomineeRelation", event.target.value)} /></label>
        <label className="form-field">Follow-up date<input type="date" value={form.followUp} onChange={(event) => update("followUp", event.target.value)} /></label>
      </div>
      <div className="form-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary" disabled={busy}>{busy ? "Saving…" : "Save patient"} <Check size={15} /></button></div>
    </form>
  </div>;
}

function SettingsPage({ user, doctorName, onLogout }: { user: User; doctorName: string; onLogout: () => void }) {
  return <>
    <PageHeading eyebrow="ACCOUNT" title="Settings" subtitle="View your authenticated account and workspace access." />
    <div className="settings-grid"><div className="card settings-card"><div className="settings-profile"><span className="avatar avatar-doctor large-doctor-avatar">{initials(doctorName || user.email || "D")}</span><div><h2>{doctorName || "Doctor account"}</h2><p>Doctor workspace · Supabase authentication</p></div></div><div className="settings-section"><h3>Profile information</h3><div className="settings-info"><span>Email address</span><b>{user.email}</b></div><div className="settings-info"><span>Account ID</span><b>{user.id}</b></div><div className="settings-info"><span>Authentication</span><b>Email and password</b></div></div><div className="settings-section"><h3>Workspace</h3><div className="settings-info"><span>Role</span><b>Doctor</b></div><div className="settings-info"><span>Data access</span><b>Assigned patients only</b></div></div><button className="button button-secondary logout-button" onClick={onLogout}><LogOut size={15} /> Sign out</button></div><div className="card settings-side"><span className="safety-shield"><ShieldCheck size={20} /></span><h3>Clinical safety matters</h3><p>CareSync supports your workflow. Verify uploaded source material and all care-plan details before approval.</p><span className="environment-pill">Private workspace</span></div></div>
  </>;
}

function Login({ onLogin, onRequestPasswordReset, initialError }: {
  onLogin: (email: string, password: string) => Promise<void>;
  onRequestPasswordReset: (email: string) => Promise<void>;
  initialError: string;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState(initialError);
  const [mode, setMode] = useState<"login" | "recovery">("login");
  const [notice, setNotice] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const configured = supabaseConfigured;
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await onLogin(email.trim(), password);
    } catch (loginError) {
      const message = errorMessage(loginError);
      setError(message.toLowerCase().includes("invalid login credentials")
        ? "Email or password not recognized. Check your details, or reset your password. If you have not been invited, ask your administrator to provision your doctor account."
        : message);
    } finally {
      setSubmitting(false);
    }
  };
  const requestReset = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    setNotice("");
    setSubmitting(true);
    try {
      await onRequestPasswordReset(email.trim());
      setNotice("If an account exists for this email, password-reset instructions will be sent.");
    } catch (resetError) {
      setError(errorMessage(resetError));
    } finally {
      setSubmitting(false);
    }
  };
  return <div className="login-screen"><div className="login-brand"><span className="brand-mark"><Activity size={21} strokeWidth={2.7} /></span><span>care<span className="brand-light">sync</span><small>DOCTOR PORTAL</small></span></div><div className="login-card"><span className="login-icon"><Stethoscope size={21} /></span><h1>{mode === "login" ? "Doctor sign in" : "Reset your password"}</h1><p>{mode === "login" ? "Sign in to your CareSync workspace." : "We’ll email reset instructions if this doctor account exists."}</p>
    {!configured && <div className="login-config-error" role="alert"><ShieldCheck size={15} /> Supabase is not configured. Copy the Supabase URL and anon key into your local <code>.env</code> file and restart the app.</div>}
    {mode === "login" ? <form onSubmit={(event) => void submit(event)}><label>Email address<input type="email" required value={email} onChange={(event) => setEmail(event.target.value)} placeholder="doctor@hospital.com" autoComplete="username" /></label><label>Password<input type="password" required value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Password" autoComplete="current-password" /></label>{error && <p className="login-error" role="alert">{error}</p>}<button className="button button-primary login-submit" type="submit" disabled={!configured || submitting}>{submitting ? "Signing in…" : "Sign in"} <ArrowRight size={15} /></button><button className="login-link" type="button" onClick={() => { setMode("recovery"); setError(""); setNotice(""); }}>Forgot password?</button></form>
      : <form onSubmit={(event) => void requestReset(event)}><label>Email address<input type="email" required value={email} onChange={(event) => setEmail(event.target.value)} placeholder="doctor@hospital.com" autoComplete="email" /></label>{error && <p className="login-error" role="alert">{error}</p>}{notice && <p className="login-notice" role="status">{notice}</p>}<button className="button button-primary login-submit" type="submit" disabled={!configured || submitting}>{submitting ? "Sending…" : "Send reset link"} <ArrowRight size={15} /></button><button className="login-link" type="button" onClick={() => { setMode("login"); setError(""); setNotice(""); }}>Back to sign in</button></form>}
    <div className="login-secure"><ShieldCheck size={14} /> Hospital-managed access · No public sign-up</div></div><small className="login-footer">© CareSync Health · Secure doctor sign-in</small></div>;
}

function PasswordRecovery({ onSubmit }: { onSubmit: (password: string) => Promise<void> }) {
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    if (password !== confirmation) {
      setError("The passwords do not match.");
      return;
    }
    setSubmitting(true);
    try {
      await onSubmit(password);
    } catch (updateError) {
      setError(errorMessage(updateError));
    } finally {
      setSubmitting(false);
    }
  };
  return <div className="login-screen"><div className="login-brand"><span className="brand-mark"><Activity size={21} strokeWidth={2.7} /></span><span>care<span className="brand-light">sync</span><small>DOCTOR PORTAL</small></span></div><div className="login-card"><span className="login-icon"><ShieldCheck size={21} /></span><h1>Choose a new password</h1><p>Set a new password for your doctor account.</p><form onSubmit={(event) => void submit(event)}><label>New password<input type="password" required minLength={6} maxLength={128} autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} /></label><label>Confirm new password<input type="password" required minLength={6} maxLength={128} autoComplete="new-password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} /></label>{error && <p className="login-error" role="alert">{error}</p>}<button className="button button-primary login-submit" type="submit" disabled={submitting}>{submitting ? "Updating…" : "Update password"} <ArrowRight size={15} /></button></form><div className="login-secure"><ShieldCheck size={14} /> Password reset link is single-use</div></div><small className="login-footer">© CareSync Health · Secure doctor sign-in</small></div>;
}

export default App;
