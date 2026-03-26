function nstates = pick_representative_nstates(nstates_list)
% PICK_REPRESENTATIVE_NSTATES  Select a single representative nstates from a list.
%
%   nstates = pick_representative_nstates(nstates_list)
%
%   Returns the upper-median element of the sorted nstates_list.  For an
%   odd-length list this is the true median; for an even-length list it is
%   the larger of the two middle elements.
%
%   Rationale: the representative nstates is used for semantic test cases
%   whose purpose is to verify operator correctness for a particular
%   parameter combination, not to probe state-space-size behaviour.  The
%   upper-median gives a state that is neither trivially small (which might
%   hide bugs related to coherence-order indexing) nor unnecessarily large
%   (which would bloat the golden record without adding coverage).
%
%   Examples
%   --------
%     pick_representative_nstates([4, 8, 16])     -> 8
%     pick_representative_nstates([4, 8, 16, 32]) -> 16
%     pick_representative_nstates([32])           -> 32
%     pick_representative_nstates([4, 8])         -> 8
%
%   See also: expand_case_templates

sorted  = sort(nstates_list(:)');
nstates = sorted(ceil(numel(sorted) / 2));

end
