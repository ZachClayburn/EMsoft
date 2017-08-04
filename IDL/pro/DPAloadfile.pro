;
; Copyright (c) 2016, Marc De Graef/Carnegie Mellon University
; All rights reserved.
;
; Redistribution and use in.dyliburce and binary forms, with or without modification, are 
; permitted provided that the following conditions are met:
;
;     - Redistributions of.dyliburce code must retain the above copyright notice, this list 
;        of conditions and the following disclaimer.
;     - Redistributions in binary form must reproduce the above copyright notice, this 
;        list of conditions and the following disclaimer in the documentation and/or 
;        other materials provided with the distribution.
;     - Neither the names of Marc De Graef, Carnegie Mellon University nor the names 
;        of its contributors may be used to endorse or promote products derived from 
;        this.dylibftware without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
; USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
; ###################################################################
;--------------------------------------------------------------------------
; E.dylibft:DPAloadfile.pro
;--------------------------------------------------------------------------
;
; PROGRAM: DPAloadfile.pro
;
;> @author Marc De Graef, Carnegie Mellon University
;
;> @brief Reads the HDF data files produced by the EMEBSDDI.f90 program
;
;> @date 06/28/16 MDG 1.0 first attempt 
;--------------------------------------------------------------------------
pro DPAloadfile,dummy
;
;------------------------------------------------------------
; common blocks
common DPA_widget_common, DPAwidget_s
common DPA_data_common, DPAcommon, DPAdata


    Core_Print,' ',/blank

EMdatapathname = Core_getenv(/data)
cp = DPAcommon.currentphase

hdfname = DPAdata[cp].dppathname+'/'+DPAdata[cp].dpfilename

; first make sure that this is indeed an HDF file
res = H5F_IS_HDF5(hdfname)
if (res eq 0) then begin
    Core_Print,'  This is not an HDF file ! ',/blank
  goto,skipall
endif

; ok,.dylib it is an HDF file; let's open it
file_id = H5F_OPEN(hdfname)
if (file_id eq -1L) then begin
    Core_Print,'  Error opening file',/blank
  goto, skipall
endif 


;  open and read the ProgramName dataset
group_id = H5G_open(file_id,'EMheader')

dset_id = H5D_open(group_id,'ProgramName')
z = H5D_read(dset_id) 
progname = strtrim(z[0],2)
H5D_close,dset_id
    Core_Print,' ->Dot Product file generated by program '+progname+'<-'
    Core_Print,'   File size : '+string(DPAdata[cp].dpfilesize,format="(I12)")+' bytes'
H5G_close,group_id


; open the NML parameters group
group_id = H5G_open(file_id,'NMLparameters/EBSDIndexingNameListType')

; max number of near-matches
dset_id = H5D_open(group_id,'nnk')
var = H5D_read(dset_id) 
DPAdata[cp].nnk = var[0]
H5D_close,dset_id

; IPF width
dset_id = H5D_open(group_id,'ipf_wd')
var = H5D_read(dset_id) 
DPAdata[cp].ipf_wd = var[0]
H5D_close,dset_id

; IPFheight
dset_id = H5D_open(group_id,'ipf_ht')
var = H5D_read(dset_id) 
DPAdata[cp].ipf_ht = var[0]
H5D_close,dset_id

; ctffile
dset_id = H5D_open(group_id,'ctffile')
var = H5D_read(dset_id) 
DPAdata[cp].ctffile = var[0]
H5D_close,dset_id

H5G_close,group_id

; and read all the dot product and related variables that may be needed by this program...
group_id = H5G_open(file_id,'Scan 1/EBSD/Data')
dset_id = H5D_open(group_id,'FZcnt')
var = H5D_read(dset_id) 
DPAdata[cp].FZcnt = var[0]
H5D_close,dset_id

dset_id = H5D_open(group_id,'NumExptPatterns')
var = H5D_read(dset_id) 
DPAdata[cp].Nexp = var[0]
H5D_close,dset_id

dset_id = H5D_open(group_id,'Ncubochoric')
var = H5D_read(dset_id) 
DPAdata[cp].Ncubochoric = var[0]
H5D_close,dset_id

dset_id = H5D_open(group_id,'PointGroupNumber')
var = H5D_read(dset_id) 
DPAdata[cp].pgnum = var[0]
H5D_close,dset_id

dset_id = H5D_open(group_id,'AvDotProductMap')
var = H5D_read(dset_id) 
dims = size(var,/dim)
*DPAdata[cp].ADPmap = bytarr(dims)
(*DPAdata[cp].ADPmap)[0,0] = var
H5D_close,dset_id

dset_id = H5D_open(group_id,'CI')
var = H5D_read(dset_id) 
dims = size(var,/dim)
*DPAdata[cp].CI = var; fltarr(dims)
;(*DPAdata[cp].CI)[0] = var
H5D_close,dset_id

dset_id = H5D_open(group_id,'IQ')
var = H5D_read(dset_id) 
dims = size(var,/dim)
*DPAdata[cp].IQ = fltarr(dims)
(*DPAdata[cp].IQ)[0] = var
H5D_close,dset_id

dset_id = H5D_open(group_id,'EulerAngles')
var = H5D_read(dset_id)  * !dtor
dims = size(var,/dim)
*DPAdata[cp].EulerAngles = fltarr(dims)
(*DPAdata[cp].EulerAngles)[0,0] = var
H5D_close,dset_id

dset_id = H5D_open(group_id,'Phi1')
var = H5D_read(dset_id) 
Phi1 = var*!dtor
H5D_close,dset_id
Phi1 = Phi1[0L:DPAdata[cp].Nexp-1L]

dset_id = H5D_open(group_id,'Phi')
var = H5D_read(dset_id) 
Phi = var*!dtor
H5D_close,dset_id
Phi = Phi[0L:DPAdata[cp].Nexp-1L]

dset_id = H5D_open(group_id,'Phi2')
var = H5D_read(dset_id) 
Phi2 = var*!dtor
H5D_close,dset_id
Phi2 = Phi2[0L:DPAdata[cp].Nexp-1L]

; collect the Euler angles in a single array
Eulers = fltarr(3L,DPAdata[cp].Nexp)
Eulers[0,0:*] = Phi1[0:*]
Eulers[1,0:*] = Phi[0:*]
Eulers[2,0:*] = Phi2[0:*]
dims = size(Eulers,/dim)
*DPAdata[cp].Eulers = fltarr(dims)
(*DPAdata[cp].Eulers)[0,0] = Eulers

dset_id = H5D_open(group_id,'TopDotProductList')
var = H5D_read(dset_id) 
var = var[0L:DPAdata[cp].nnk-1L,0L:DPAdata[cp].Nexp-1L]
dims = size(var,/dim)
*DPAdata[cp].tdp = fltarr(dims)
(*DPAdata[cp].tdp)[0,0] = var
H5D_close,dset_id

dset_id = H5D_open(group_id,'TopMatchIndices')
var = H5D_read(dset_id) 
var = var[0L:DPAdata[cp].nnk-1L,0L:DPAdata[cp].Nexp-1L]
dims = size(var,/dim)
*DPAdata[cp].tmi = lonarr(dims)
(*DPAdata[cp].tmi)[0,0] = var
H5D_close,dset_id


H5G_close,group_id
H5F_close,file_id


    Core_Print,'Completed reading data file',/blank


skipall:


stop

end
