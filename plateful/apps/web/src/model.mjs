export const moods = ['bright', 'steady', 'tough'];
export const appetites = ['low', 'comfortable', 'hungry'];
export const routines = ['nutrition', 'movement', 'reflection'];
export function todayKey(date = new Date()) {return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;}
export function createCheckin({date,mood,appetite,selectedRoutines=[],note=''}) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date||'') || Number.isNaN(Date.parse(`${date}T12:00:00Z`)) || new Date(`${date}T12:00:00Z`).toISOString().slice(0,10)!==date) throw new Error('Choose a valid day.');
  if (!moods.includes(mood)) throw new Error('Choose how you feel today.');
  if (!appetites.includes(appetite)) throw new Error('Choose an appetite check-in.');
  if (!Array.isArray(selectedRoutines) || selectedRoutines.some(item=>!routines.includes(item))) throw new Error('Unknown routine.');
  if (typeof note!=='string' || note.length>500) throw new Error('Keep your note to 500 characters.');
  return {id:date,date,mood,appetite,routines:[...new Set(selectedRoutines)],note:note.trim(),sample:false};
}
export function saveCheckin(entries,checkin) {return [...entries.filter(entry=>entry.id!==checkin.id),checkin].sort((a,b)=>b.date.localeCompare(a.date));}
export function earnedMilestones(entries) {
  const own=entries.filter(entry=>!entry.sample);
  return [
    {id:'first',name:'A little hello',description:'Make your first check-in.',earned:own.length>0,symbol:'sun'},
    {id:'reflection',name:'Space to reflect',description:'Write a note or mark reflection.',earned:own.some(entry=>entry.note||entry.routines.includes('reflection')),symbol:'leaf'},
    {id:'movement',name:'Moved your way',description:'Mark a moment of movement.',earned:own.some(entry=>entry.routines.includes('movement')),symbol:'spark'},
  ];
}
export function cleanEmail(value) {const email=String(value||'').trim().toLowerCase();return email.length<=254&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)?email:null;}
