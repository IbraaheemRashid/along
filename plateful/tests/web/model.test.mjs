import test from 'node:test';
import assert from 'node:assert/strict';
import {createCheckin,earnedMilestones,saveCheckin,todayKey} from '../../apps/web/src/model.mjs';
import {joinWaitlist,waitlistConfiguration} from '../../apps/web/src/waitlist.mjs';
const valid={date:'2026-11-01',mood:'steady',appetite:'comfortable',selectedRoutines:[],note:''};
test('check-in validates user choices and calendar date',()=>{
  assert.throws(()=>createCheckin({...valid,date:'2026-02-30'}));
  assert.throws(()=>createCheckin({...valid,mood:'invented'}));
  assert.throws(()=>createCheckin({...valid,mood:''}));
  assert.throws(()=>createCheckin({...valid,appetite:''}));
  assert.equal(createCheckin({...valid,note:'x'.repeat(500)}).note.length,500);
  assert.throws(()=>createCheckin({...valid,appetite:'invented'}));
  assert.throws(()=>createCheckin({...valid,selectedRoutines:['dosing']}));
  assert.throws(()=>createCheckin({...valid,note:'x'.repeat(501)}));
  const result=createCheckin({...valid,selectedRoutines:['movement','movement'],note:'  A walk  '});
  assert.deepEqual(result.routines,['movement']);assert.equal(result.note,'A walk');
});
test('editing a day replaces it without inflating progress',()=>{
  const original=createCheckin(valid),updated=createCheckin({...valid,mood:'bright'});
  const prior=createCheckin({...valid,date:'2026-10-31'});
  const entries=saveCheckin([original,prior],updated);
  assert.equal(entries.length,2);assert.equal(entries[0].mood,'bright');assert.equal(entries[1].date,'2026-10-31');
});
test('milestones reflect actual preview actions, not sample records',()=>{
  assert.deepEqual(earnedMilestones([{...createCheckin({...valid,note:'Example',selectedRoutines:['movement']}),sample:true}]).map(x=>x.earned),[false,false,false]);
  assert.deepEqual(earnedMilestones([createCheckin(valid)]).map(x=>x.earned),[true,false,false]);
  assert.deepEqual(earnedMilestones([createCheckin({...valid,note:'Walked to the park',selectedRoutines:['movement']})]).map(x=>x.earned),[true,true,true]);
});
test('day key uses the local calendar',()=>assert.equal(todayKey(new Date(2026,0,2,23,59)),'2026-01-02'));
test('waitlist fails closed and cannot report an unaccepted email as joined',async()=>{
  let requests=0;const fetcher=async()=>{requests++;return {ok:true,json:async()=>({accepted:false})};};
  assert.equal(waitlistConfiguration({VITE_WAITLIST_ENABLED:'true'}).enabled,false);
  await assert.rejects(joinWaitlist({config:waitlistConfiguration({}),email:'person@example.com',consent:true,token:'test',fetcher}),/preview/);assert.equal(requests,0);
  await assert.rejects(joinWaitlist({config:{enabled:true,api:'https://example.com'},email:'person@example.com',consent:true,token:'test',fetcher}),/could not save/);assert.equal(requests,1);
});
