!################################################################################
!This file is part of Incompact3d.
!
!Incompact3d
!Copyright (c) 2012 Eric Lamballais and Sylvain Laizet
!eric.lamballais@univ-poitiers.fr / sylvain.laizet@gmail.com
!
!    Incompact3d is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation.
!
!    Incompact3d is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with the code.  If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
!    We kindly request that you cite Incompact3d in your publications and 
!    presentations. The following citations are suggested:
!
!    1-Laizet S. & Lamballais E., 2009, High-order compact schemes for 
!    incompressible flows: a simple and efficient method with the quasi-spectral 
!    accuracy, J. Comp. Phys.,  vol 228 (15), pp 5989-6015
!
!    2-Laizet S. & Li N., 2011, Incompact3d: a powerful tool to tackle turbulence 
!    problems with up to 0(10^5) computational cores, Int. J. of Numerical 
!    Methods in Fluids, vol 67 (11), pp 1735-1757
!################################################################################

!*******************************************************************
!
subroutine test_scalar_min_max(phi)
!
!*******************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI


implicit none

integer :: i,j,k
real(mytype) :: phimax,phimin,cfl
real(mytype) :: phimax1,phimin1

real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: phi
integer :: code

phimax=-1609.
phimin=1609.
do k=1,xsize(3)
do j=1,xsize(2)
do i=1,xsize(1)
   if (phi(i,j,k).gt.phimax) phimax=phi(i,j,k)
   if (phi(i,j,k).lt.phimin) phimin=phi(i,j,k)
enddo
enddo
enddo


call MPI_REDUCE(phimax,phimax1,1,real_type,MPI_MAX,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(phimin,phimin1,1,real_type,MPI_MIN,0,MPI_COMM_WORLD,code)
if (nrank==0) then
   print *,'PHI max=',phimax1
   print *,'PHI min=',phimin1
endif


return
end subroutine test_scalar_min_max

!*******************************************************************
!
subroutine test_speed_min_max(ux,uy,uz)
!
!*******************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI


implicit none

integer :: i,j,k
real(mytype) :: uxmax,uymax,uzmax,uxmin,uymin,uzmin,cfl
real(mytype) :: uxmax1,uymax1,uzmax1,uxmin1,uymin1,uzmin1

real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux,uy,uz
integer :: code

uxmax=-1609.
uymax=-1609.
uzmax=-1609.
uxmin=1609.
uymin=1609.
uzmin=1609.
do k=1,xsize(3)
do j=1,xsize(2)
do i=1,xsize(1)
   if (ux(i,j,k).gt.uxmax) uxmax=ux(i,j,k)
   if (uy(i,j,k).gt.uymax) uymax=uy(i,j,k)
   if (uz(i,j,k).gt.uzmax) uzmax=uz(i,j,k)
   if (ux(i,j,k).lt.uxmin) uxmin=ux(i,j,k)
   if (uy(i,j,k).lt.uymin) uymin=uy(i,j,k)
   if (uz(i,j,k).lt.uzmin) uzmin=uz(i,j,k)
enddo
enddo
enddo


call MPI_REDUCE(uxmax,uxmax1,1,real_type,MPI_MAX,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(uymax,uymax1,1,real_type,MPI_MAX,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(uzmax,uzmax1,1,real_type,MPI_MAX,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(uxmin,uxmin1,1,real_type,MPI_MIN,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(uymin,uymin1,1,real_type,MPI_MIN,0,MPI_COMM_WORLD,code)
call MPI_REDUCE(uzmin,uzmin1,1,real_type,MPI_MIN,0,MPI_COMM_WORLD,code)
if (nrank==0) then
   print *,'U,V,W max=',uxmax1,uymax1,uzmax1
   print *,'U,V,W min=',uxmin1,uymin1,uzmin1
endif

call cfl_compute(uxmax,uymax,uzmax)

return
end subroutine test_speed_min_max

!*******************************************************************
!
subroutine restart(ux1,uy1,uz1,ep1,pp3,phi1,gx1,gy1,gz1,px1,py1,pz1,phis1,&
                   hx1,hy1,hz1,phiss1,phG,irestart)
!
!*******************************************************************

USE decomp_2d
USE decomp_2d_io
USE param
USE MPI

implicit none

TYPE(DECOMP_INFO) :: phG
integer :: i,j,k,irestart,nzmsize,fh,ierror,code
real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1,ep1
real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: gx1,gy1,gz1
real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: hx1,hy1,hz1
real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: px1,py1,pz1
real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: phi1, phis1, phiss1
real(mytype), dimension(phG%zst(1):phG%zen(1),phG%zst(2):phG%zen(2),phG%zst(3):phG%zen(3)) :: pp3
integer (kind=MPI_OFFSET_KIND) :: filesize, disp
real(mytype) :: xdt
integer, dimension(2) :: dims, dummy_coords
logical, dimension(2) :: dummy_periods

if (iscalar==0) then
   if (nscheme.ne.4) then
      if (irestart==1) then !write
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL, &
              fh, ierror)
         filesize = 0_MPI_OFFSET_KIND
         call MPI_FILE_SET_SIZE(fh,filesize,ierror)  ! guarantee overwriting
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_write_var(fh,disp,1,ux1)
         call decomp_2d_write_var(fh,disp,1,uy1)
         call decomp_2d_write_var(fh,disp,1,uz1)
         call decomp_2d_write_var(fh,disp,1,gx1)
         call decomp_2d_write_var(fh,disp,1,gy1)
         call decomp_2d_write_var(fh,disp,1,gz1)
         call decomp_2d_write_var(fh,disp,1,px1)
         call decomp_2d_write_var(fh,disp,1,py1)
         call decomp_2d_write_var(fh,disp,1,pz1)
         call decomp_2d_write_var(fh,disp,1,pp3,phG)
         call MPI_FILE_CLOSE(fh,ierror)
      else
         if (nrank==0) print *,'RESTART'
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_RDONLY, MPI_INFO_NULL, &
              fh, ierror)
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_read_var(fh,disp,1,ux1)   
         call decomp_2d_read_var(fh,disp,1,uy1)
         call decomp_2d_read_var(fh,disp,1,uz1)
         call decomp_2d_read_var(fh,disp,1,gx1)
         call decomp_2d_read_var(fh,disp,1,gy1)
         call decomp_2d_read_var(fh,disp,1,gz1)
         call decomp_2d_read_var(fh,disp,1,px1)
         call decomp_2d_read_var(fh,disp,1,py1)
         call decomp_2d_read_var(fh,disp,1,pz1)
         call decomp_2d_read_var(fh,disp,1,pp3,phG)
         call MPI_FILE_CLOSE(fh,ierror)
      endif
   else !AB3
     if (irestart==1) then !write
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL, &
              fh, ierror)
         filesize = 0_MPI_OFFSET_KIND
         call MPI_FILE_SET_SIZE(fh,filesize,ierror)  ! guarantee overwriting
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_write_var(fh,disp,1,ux1)
         call decomp_2d_write_var(fh,disp,1,uy1)
         call decomp_2d_write_var(fh,disp,1,uz1)
         call decomp_2d_write_var(fh,disp,1,gx1)
         call decomp_2d_write_var(fh,disp,1,gy1)
         call decomp_2d_write_var(fh,disp,1,gz1)
         call decomp_2d_write_var(fh,disp,1,hx1)
         call decomp_2d_write_var(fh,disp,1,hy1)
         call decomp_2d_write_var(fh,disp,1,hz1)
         call decomp_2d_write_var(fh,disp,1,px1)
         call decomp_2d_write_var(fh,disp,1,py1)
         call decomp_2d_write_var(fh,disp,1,pz1)
         call decomp_2d_write_var(fh,disp,1,pp3,phG)
         call MPI_FILE_CLOSE(fh,ierror)
      else
         if (nrank==0) print *,'RESTART'
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_RDONLY, MPI_INFO_NULL, &
              fh, ierror)
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_read_var(fh,disp,1,ux1)   
         call decomp_2d_read_var(fh,disp,1,uy1)
         call decomp_2d_read_var(fh,disp,1,uz1)
         call decomp_2d_read_var(fh,disp,1,gx1)
         call decomp_2d_read_var(fh,disp,1,gy1)
         call decomp_2d_read_var(fh,disp,1,gz1)
         call decomp_2d_read_var(fh,disp,1,hx1)
         call decomp_2d_read_var(fh,disp,1,hy1)
         call decomp_2d_read_var(fh,disp,1,hz1)
         call decomp_2d_read_var(fh,disp,1,px1)
         call decomp_2d_read_var(fh,disp,1,py1)
         call decomp_2d_read_var(fh,disp,1,pz1)
         call decomp_2d_read_var(fh,disp,1,pp3,phG)
         call MPI_FILE_CLOSE(fh,ierror)
      endif 
   endif
else !SCALAR 
if (nscheme.ne.4) then
      if (irestart==1) then !write
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL, &
              fh, ierror)
         filesize = 0_MPI_OFFSET_KIND
         call MPI_FILE_SET_SIZE(fh,filesize,ierror)  ! guarantee overwriting
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_write_var(fh,disp,1,ux1)
         call decomp_2d_write_var(fh,disp,1,uy1)
         call decomp_2d_write_var(fh,disp,1,uz1)
         call decomp_2d_write_var(fh,disp,1,gx1)
         call decomp_2d_write_var(fh,disp,1,gy1)
         call decomp_2d_write_var(fh,disp,1,gz1)
         call decomp_2d_write_var(fh,disp,1,px1)
         call decomp_2d_write_var(fh,disp,1,py1)
         call decomp_2d_write_var(fh,disp,1,pz1)
         call decomp_2d_write_var(fh,disp,1,pp3,phG)
         call decomp_2d_write_var(fh,disp,1,phi1)
         call decomp_2d_write_var(fh,disp,1,phis1)
         call MPI_FILE_CLOSE(fh,ierror)
      else
         if (nrank==0) print *,'RESTART'
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_RDONLY, MPI_INFO_NULL, &
              fh, ierror)
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_read_var(fh,disp,1,ux1)   
         call decomp_2d_read_var(fh,disp,1,uy1)
         call decomp_2d_read_var(fh,disp,1,uz1)
         call decomp_2d_read_var(fh,disp,1,gx1)
         call decomp_2d_read_var(fh,disp,1,gy1)
         call decomp_2d_read_var(fh,disp,1,gz1)
         call decomp_2d_read_var(fh,disp,1,px1)
         call decomp_2d_read_var(fh,disp,1,py1)
         call decomp_2d_read_var(fh,disp,1,pz1)
         call decomp_2d_read_var(fh,disp,1,pp3,phG)
         call decomp_2d_read_var(fh,disp,1,phi1)
         call decomp_2d_read_var(fh,disp,1,phis1)
         call MPI_FILE_CLOSE(fh,ierror)
      endif
   else !SCALAR + AB3
     if (irestart==1) then !write
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL, &
              fh, ierror)
         filesize = 0_MPI_OFFSET_KIND
         call MPI_FILE_SET_SIZE(fh,filesize,ierror)  ! guarantee overwriting
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_write_var(fh,disp,1,ux1)
         call decomp_2d_write_var(fh,disp,1,uy1)
         call decomp_2d_write_var(fh,disp,1,uz1)
         call decomp_2d_write_var(fh,disp,1,gx1)
         call decomp_2d_write_var(fh,disp,1,gy1)
         call decomp_2d_write_var(fh,disp,1,gz1)
         call decomp_2d_write_var(fh,disp,1,hx1)
         call decomp_2d_write_var(fh,disp,1,hy1)
         call decomp_2d_write_var(fh,disp,1,hz1)
         call decomp_2d_write_var(fh,disp,1,px1)
         call decomp_2d_write_var(fh,disp,1,py1)
         call decomp_2d_write_var(fh,disp,1,pz1)
         call decomp_2d_write_var(fh,disp,1,pp3,phG)
         call decomp_2d_write_var(fh,disp,1,phi1)
         call decomp_2d_write_var(fh,disp,1,phis1)
         call decomp_2d_write_var(fh,disp,1,phiss1)
         call MPI_FILE_CLOSE(fh,ierror)
      else
         if (nrank==0) print *,'RESTART'
         call MPI_FILE_OPEN(MPI_COMM_WORLD, 'sauve.dat', &
              MPI_MODE_RDONLY, MPI_INFO_NULL, &
              fh, ierror)
         disp = 0_MPI_OFFSET_KIND
         call decomp_2d_read_var(fh,disp,1,ux1)   
         call decomp_2d_read_var(fh,disp,1,uy1)
         call decomp_2d_read_var(fh,disp,1,uz1)
         call decomp_2d_read_var(fh,disp,1,gx1)
         call decomp_2d_read_var(fh,disp,1,gy1)
         call decomp_2d_read_var(fh,disp,1,gz1)
         call decomp_2d_read_var(fh,disp,1,hx1)
         call decomp_2d_read_var(fh,disp,1,hy1)
         call decomp_2d_read_var(fh,disp,1,hz1)
         call decomp_2d_read_var(fh,disp,1,px1)
         call decomp_2d_read_var(fh,disp,1,py1)
         call decomp_2d_read_var(fh,disp,1,pz1)
         call decomp_2d_read_var(fh,disp,1,pp3,phG)
         call decomp_2d_read_var(fh,disp,1,phi1)
         call decomp_2d_read_var(fh,disp,1,phis1)
         call decomp_2d_read_var(fh,disp,1,phiss1)
         call MPI_FILE_CLOSE(fh,ierror)
      endif 
   endif
endif

if (irestart==0) then
! reconstruction of the dp/dx, dp/dy and dp/dz from px1,py1 and pz1
! Temporal scheme (1:AB2, 2: RK3, 3:RK4, 4:AB3)
   if (nscheme==1) xdt=adt(1)+bdt(1)
   if (nscheme==2) xdt=(3./4.)*dt + (-5./12.)*dt
   if (nscheme==3) xdt=0.041717869325*dt
   if (nscheme==4) xdt=adt(1)+bdt(1)+cdt(1)
   
   do k=1,xsize(3)
   do j=1,xsize(2)
      dpdyx1(j,k)=py1(1,j,k)/xdt
      dpdzx1(j,k)=pz1(1,j,k)/xdt
      dpdyxn(j,k)=py1(nx,j,k)/xdt
      dpdzxn(j,k)=pz1(nx,j,k)/xdt
   enddo
   enddo
   
   if (xsize(3)==1) then
      do j=1,xsize(2)
      do i=1,xsize(1)
         dpdxz1(i,j)=px1(i,j,1)/xdt
         dpdyz1(i,j)=py1(i,j,1)/xdt
      enddo
      enddo
   endif
   if (xsize(3)==nz) then
      do j=1,xsize(2)
      do i=1,xsize(1)
         dpdxzn(i,j)=px1(i,j,nz)/xdt
         dpdyzn(i,j)=py1(i,j,nz)/xdt
      enddo
      enddo
   endif

   ! determine the processor grid in use
   call MPI_CART_GET(DECOMP_2D_COMM_CART_X, 2, &
         dims, dummy_periods, dummy_coords, code)

   if (dims(1)==1) then
      do k=1,xsize(3)
      do i=1,xsize(1)
      dpdxy1(i,k)=px1(i,1,k)/xdt
      dpdzy1(i,k)=pz1(i,1,k)/xdt
      enddo
      enddo
      do k=1,xsize(3)
      do i=1,xsize(1)
      dpdxyn(i,k)=px1(i,xsize(2),k)/xdt
      dpdzyn(i,k)=pz1(i,xsize(2),k)/xdt
      enddo
      enddo
   else
!find j=1 and j=ny
      if (xstart(2)==1) then
         do k=1,xsize(3)
         do i=1,xsize(1)
         dpdxy1(i,k)=px1(i,1,k)/xdt
         dpdzy1(i,k)=pz1(i,1,k)/xdt
         enddo
         enddo
      endif
!      print *,nrank,xstart(2),ny-(nym/p_row)
       if (ny-(nym/dims(1))==xstart(2)) then
         do k=1,xsize(3)
         do i=1,xsize(1)
         dpdxyn(i,k)=px1(i,xsize(2),k)/xdt
         dpdzyn(i,k)=pz1(i,xsize(2),k)/xdt
         enddo
         enddo
      endif

   endif


   if (nrank==0) print *,'reconstruction pressure gradients done!'
endif

if (irestart==0) then
if (ivirt==2) then
   call MPI_FILE_OPEN(MPI_COMM_WORLD, 'epsilon.dat', &
        MPI_MODE_RDONLY, MPI_INFO_NULL, &
        fh, ierror)
   disp = 0_MPI_OFFSET_KIND
   call decomp_2d_read_var(fh,disp,1,ep1) 
   call MPI_FILE_CLOSE(fh,ierror)
   if (nrank==0) print *,'read epsilon file done from restart'
endif
endif

end subroutine restart

! ************************************************************************
subroutine read_inflow(ux1,uy1,uz1,ifileinflow)
!
! ************************************************************************

USE decomp_2d
USE decomp_2d_io
use var, only: ux_inflow, uy_inflow, uz_inflow
USE param
use actuator_line_model_utils
USE MPI

implicit none

TYPE(DECOMP_INFO) :: phG
integer :: i,j,k,irestart,nzmsize,fh,ierror,code, ifileinflow
real(mytype), dimension(NTimeSteps,xsize(2),xsize(3)) :: ux1,uy1,uz1
integer (kind=MPI_OFFSET_KIND) :: filesize, disp
real(mytype) :: xdt
integer, dimension(2) :: dims, dummy_coords
logical, dimension(2) :: dummy_periods

if (iscalar==0) then
    if (nrank==0) print *,'READING INFLOW from ',trim(InflowPath)//'inflow'//trim(int2str(ifileinflow+1)) 
    call MPI_FILE_OPEN(MPI_COMM_WORLD, trim(InflowPath)//'inflow'//trim(int2str(ifileinflow+1)), &
         MPI_MODE_RDONLY, MPI_INFO_NULL, &
         fh, ierror)
    disp = 0_MPI_OFFSET_KIND
    call decomp_2d_read_inflow(fh,disp,NTimeSteps,ux_inflow)   
    call decomp_2d_read_inflow(fh,disp,NTimeSteps,uy_inflow)
    call decomp_2d_read_inflow(fh,disp,NTimeSteps,uz_inflow)
    call MPI_FILE_CLOSE(fh,ierror)
endif

end subroutine read_inflow


! ***********************************************************************
subroutine append_outflow(ux,uy,uz,timestep)
!
! ***********************************************************************
    USE decomp_2d
    USE decomp_2d_io
    use var, only: ux_recOutflow, uy_recOutflow, uz_recOutflow
    USE param

implicit none

real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: ux,uy,uz
integer, intent(in) :: timestep
integer :: i,j,k

if (nrank==0) print *, 'Writing outflow', timestep 
! Record planes in the middle
if (timestep<1.or.timestep>NTimeSteps) then 
print*, 'timesteps should be between 1 and NTimesteps -- I exit without writing'
return
endif

do k=1,xsize(3)
do j=1,xsize(2)
ux_recOutflow(timestep,j,k)=ux(xend(1),j,k)
uy_recOutflow(timestep,j,k)=uy(xend(1),j,k)
uz_recOutflow(timestep,j,k)=uz(xend(1),j,k)
enddo
enddo

return
end subroutine append_outflow

! ***********************************************************************
subroutine write_outflow(ifileoutflow)
!
! ***********************************************************************
    USE decomp_2d
    USE decomp_2d_io
    use actuator_line_model_utils
    USE param
    use var, only: ux_recOutflow, uy_recOutflow, uz_recOutflow
    USE MPI

implicit none

integer,intent(in) :: ifileoutflow
TYPE(DECOMP_INFO) :: phG
integer :: i,j,k,irestart,nzmsize,fh,code
integer (kind=MPI_OFFSET_KIND) :: filesize, disp
real(mytype) :: xdt
integer, dimension(2) :: dims, dummy_coords
logical, dimension(2) :: dummy_periods
TYPE(DECOMP_INFO) :: decomp
integer, dimension(3) :: sizes, subsizes, starts
integer :: ierror, newtype, data_type

if (iscalar==0) then
    if (nrank==0) print *,'WRITING OUTFLOW'
    call MPI_FILE_OPEN(MPI_COMM_WORLD, 'inflow'//trim(int2str(ifileoutflow)), &
         MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL, &
         fh, ierror)
    filesize = 0_MPI_OFFSET_KIND
    call MPI_FILE_SET_SIZE(fh,filesize,ierror)  ! guarantee overwriting
    disp = 0_MPI_OFFSET_KIND
    call decomp_2d_write_outflow(fh,disp,NTimeSteps,ux_recOutflow)
    call decomp_2d_write_outflow(fh,disp,NTimeSteps,uy_recOutflow)
    call decomp_2d_write_outflow(fh,disp,NTimeSteps,uz_recOutflow)
    call MPI_FILE_CLOSE(fh,ierror)
endif

end subroutine write_outflow


!*******************************************************************
subroutine stretching()
!
!*******************************************************************
!
USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

real(mytype) :: yinf,den,xnum,xcx,den1,den2,den3,den4,xnum1,cst
integer :: j

yinf=-yly/2.
den=2.*beta*yinf
xnum=-yinf-sqrt(pi*pi*beta*beta+yinf*yinf)
alpha=abs(xnum/den)
xcx=1./beta/alpha
if (alpha.ne.0.) then
   if (istret.eq.1) yp(1)=0.
   if (istret.eq.2) yp(1)=0.
   if (istret.eq.1) yeta(1)=0.
   if (istret.eq.2) yeta(1)=-1./2.
   if (istret.eq.3) yp(1)=0.
   if (istret.eq.3) yeta(1)=-1./2.
   do j=2,ny!-1
      if (istret==1) then
         if (ncly.eq.0) yeta(j)=(j-1.)*(1./ny)
         if ((ncly.eq.1).or.(ncly.eq.2)) yeta(j)=(j-1.)*(1./(ny-1.))
      endif
      if (istret==2) then
         if (ncly.eq.0) yeta(j)=(j-1.)*(1./ny)-0.5
         if ((ncly.eq.1).or.(ncly.eq.2)) yeta(j)=(j-1.)*(1./(ny-1.))-0.5
      endif
      if (istret==3) then
         if (ncly.eq.0) yeta(j)=((j-1.)*(1./2./ny)-0.5)
         if ((ncly.eq.1).or.(ncly.eq.2)) yeta(j)=((j-1.)*(1./2./(ny-1.))-0.5)
      endif
      den1=sqrt(alpha*beta+1.)
      xnum=den1/sqrt(alpha/pi)/sqrt(beta)/sqrt(pi)
      den=2.*sqrt(alpha/pi)*sqrt(beta)*pi*sqrt(pi)
      den3=((sin(pi*yeta(j)))*(sin(pi*yeta(j)))/beta/pi)+alpha/pi
      den4=2.*alpha*beta-cos(2.*pi*yeta(j))+1.
      if ((ncly.ne.0).and.(j==ny).and.(istret==1)) then
         xnum1=0.
      else
         xnum1=(atan(xnum*tan(pi*yeta(j))))*den4/den1/den3/den
      endif
      cst=sqrt(beta)*pi/(2.*sqrt(alpha)*sqrt(alpha*beta+1.))
      if (istret==1) then
         if (yeta(j).lt.0.5) yp(j)=xnum1-cst-yinf
         if (yeta(j).eq.0.5) yp(j)=0.-yinf
         if (yeta(j).gt.0.5) yp(j)=xnum1+cst-yinf
      endif
      if (istret==2) then
         if (yeta(j).lt.0.5) yp(j)=xnum1-cst+yly
         if (yeta(j).eq.0.5) yp(j)=0.+yly
         if (yeta(j).gt.0.5) yp(j)=xnum1+cst+yly
      endif
      if (istret==3) then
         if (yeta(j).lt.0.5) yp(j)=(xnum1-cst+yly)*2.
         if (yeta(j).eq.0.5) yp(j)=(0.+yly)*2.
         if (yeta(j).gt.0.5) yp(j)=(xnum1+cst+yly)*2.
      endif
   enddo

endif
!if (nrank==0) then
!do j=1,ny
!print *,j,yp(j),yeta(j)
!enddo
!endif
!stop
if (alpha.eq.0.) then
   yp(1)=-1.e10
   do j=2,ny
      yeta(j)=(j-1.)*(1./ny)
      yp(j)=-beta*cos(pi*yeta(j))/sin(yeta(j)*pi)
   enddo
endif
if (alpha.ne.0.) then
   do j=1,ny
      if (istret==1) then
         if (ncly.eq.0) yetai(j)=(j-0.5)*(1./ny)
         if ((ncly.eq.1).or.(ncly.eq.2)) yetai(j)=(j-0.5)*(1./(ny-1.))
      endif
      if (istret==2) then
         if (ncly.eq.0) yetai(j)=(j-0.5)*(1./ny)-0.5
         if ((ncly.eq.1).or.(ncly.eq.2)) yetai(j)=(j-0.5)*(1./(ny-1.))-0.5
      endif
      if (istret==3) then
         if (ncly.eq.0) yetai(j)=(j-0.5)*(1./2./ny)-0.5
         if ((ncly.eq.1).or.(ncly.eq.2)) yetai(j)=(j-0.5)*(1./2./(ny-1.))-0.5
      endif
      
      den1=sqrt(alpha*beta+1.)
      xnum=den1/sqrt(alpha/pi)/sqrt(beta)/sqrt(pi)
      den=2.*sqrt(alpha/pi)*sqrt(beta)*pi*sqrt(pi)
      den3=((sin(pi*yetai(j)))*(sin(pi*yetai(j)))/beta/pi)+alpha/pi
      den4=2.*alpha*beta-cos(2.*pi*yetai(j))+1.
      xnum1=(atan(xnum*tan(pi*yetai(j))))*den4/den1/den3/den
      cst=sqrt(beta)*pi/(2.*sqrt(alpha)*sqrt(alpha*beta+1.))
      if (istret==1) then
         if (yetai(j).lt.0.5) ypi(j)=xnum1-cst-yinf
         if (yetai(j).eq.0.5) ypi(j)=0.-yinf
         if (yetai(j).gt.0.5) ypi(j)=xnum1+cst-yinf
      endif
      if (istret==2) then
         if (yetai(j).lt.0.5) ypi(j)=xnum1-cst+yly
         if (yetai(j).eq.0.5) ypi(j)=0.+yly
         if (yetai(j).gt.0.5) ypi(j)=xnum1+cst+yly
      endif
      if (istret==3) then
         if (yetai(j).lt.0.5) ypi(j)=(xnum1-cst+yly)*2.
         if (yetai(j).eq.0.5) ypi(j)=(0.+yly)*2.
         if (yetai(j).gt.0.5) ypi(j)=(xnum1+cst+yly)*2.
      endif
   enddo
endif
if (alpha.eq.0.) then
   ypi(1)=-1.e10
   do j=2,ny
      yetai(j)=(j-1.)*(1./ny)
      ypi(j)=-beta*cos(pi*yetai(j))/sin(yetai(j)*pi)
   enddo
endif

do j=1,ny
   ppy(j)=yly*(alpha/pi+(1./pi/beta)*sin(pi*yeta(j))* &
        sin(pi*yeta(j)))
   pp2y(j)=ppy(j)*ppy(j)
   pp4y(j)=(-2./beta*cos(pi*yeta(j))*sin(pi*yeta(j)))
enddo
do j=1,ny
   ppyi(j)=yly*(alpha/pi+(1./pi/beta)*sin(pi*yetai(j))* &
        sin(pi*yetai(j)))
   pp2yi(j)=ppyi(j)*ppyi(j)
   pp4yi(j)=(-2./beta*cos(pi*yetai(j))*sin(pi*yetai(j)))
enddo

if (nrank==0) then
open(10,file='yp.dat', form='formatted')
do j=1,ny
write(10,*)yp(j)
enddo
close(10)
endif


end subroutine stretching

!*****************************************************************
!
subroutine inversion5_v1(aaa,eee,spI)
!
!*****************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

! decomposition object for spectral space
TYPE(DECOMP_INFO) :: spI

#ifdef DOUBLE_PREC
  real(mytype), parameter :: epsilon = 1.e-16
#else
  real(mytype), parameter :: epsilon = 1.e-8
#endif

complex(mytype),dimension(spI%yst(1):spI%yen(1),ny/2,spI%yst(3):spI%yen(3),5) :: aaa
complex(mytype),dimension(spI%yst(1):spI%yen(1),spI%yst(2):spI%yen(2),spI%yst(3):spI%yen(3)) :: eee
integer :: i,j,k,m,mi,jc
integer,dimension(2) :: ja,jb
complex(mytype),dimension(spI%yst(1):spI%yen(1),spI%yst(3):spI%yen(3)) :: sr
complex(mytype),dimension(spI%yst(1):spI%yen(1),spI%yst(3):spI%yen(3)) :: a1,b1

real(mytype) :: tmp1,tmp2,tmp3,tmp4

do i=1,2
   ja(i)=4-i
   jb(i)=5-i
enddo
do m=1,ny/2-2
   do i=1,2
      mi=m+i
      do k=spI%yst(3),spI%yen(3)
      do j=spI%yst(1),spI%yen(1) 
         if (real(aaa(j,m,k,3), kind=mytype).ne.0.) tmp1=real(aaa(j,mi,k,3-i), kind=mytype)/real(aaa(j,m,k,3), kind=mytype)
         if (aimag(aaa(j,m,k,3)).ne.0.)tmp2=aimag(aaa(j,mi,k,3-i))/aimag(aaa(j,m,k,3))
         sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
         eee(j,mi,k)=cmplx(real(eee(j,mi,k), kind=mytype)-tmp1*real(eee(j,m,k), kind=mytype),&
              aimag(eee(j,mi,k))-tmp2*aimag(eee(j,m,k)), kind=mytype)
      enddo
      enddo
      do jc=ja(i),jb(i)
      do k=spI%yst(3),spI%yen(3)
      do j=spI%yst(1),spI%yen(1) 
         aaa(j,mi,k,jc)=cmplx(real(aaa(j,mi,k,jc), kind=mytype)-real(sr(j,k), kind=mytype)*real(aaa(j,m,k,jc+i), kind=mytype),&
              aimag(aaa(j,mi,k,jc))-aimag(sr(j,k))*aimag(aaa(j,m,k,jc+i)), kind=mytype)
      enddo
      enddo
      enddo
   enddo
enddo


do k=spI%yst(3),spI%yen(3)
do j=spI%yst(1),spI%yen(1) 
   if (abs(real(aaa(j,ny/2-1,k,3), kind=mytype)).gt.epsilon) then
      tmp1=real(aaa(j,ny/2,k,2), kind=mytype)/real(aaa(j,ny/2-1,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,ny/2-1,k,3))).gt.epsilon) then
      tmp2=aimag(aaa(j,ny/2,k,2))/aimag(aaa(j,ny/2-1,k,3))
   else
      tmp2=0.
   endif
   sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   b1(j,k)=cmplx(real(aaa(j,ny/2,k,3), kind=mytype)-tmp1*real(aaa(j,ny/2-1,k,4), kind=mytype),&
        aimag(aaa(j,ny/2,k,3))-tmp2*aimag(aaa(j,ny/2-1,k,4)), kind=mytype)

   if (abs(real(b1(j,k), kind=mytype)).gt.epsilon) then
      tmp1=real(sr(j,k), kind=mytype)/real(b1(j,k), kind=mytype)
      tmp3=real(eee(j,ny/2,k), kind=mytype)/real(b1(j,k), kind=mytype)-tmp1*real(eee(j,ny/2-1,k), kind=mytype)
   else
      tmp1=0.
      tmp3=0.
   endif
   if (abs(aimag(b1(j,k))).gt.epsilon) then
      tmp2=aimag(sr(j,k))/aimag(b1(j,k))
      tmp4=aimag(eee(j,ny/2,k))/aimag(b1(j,k))-tmp2*aimag(eee(j,ny/2-1,k))
   else
      tmp2=0.
      tmp4=0.
   endif
   a1(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   eee(j,ny/2,k)=cmplx(tmp3,tmp4, kind=mytype)
   
   if (abs(real(aaa(j,ny/2-1,k,3), kind=mytype)).gt.epsilon) then
      tmp1=1./real(aaa(j,ny/2-1,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,ny/2-1,k,3))).gt.epsilon) then
      tmp2=1./aimag(aaa(j,ny/2-1,k,3))
   else
      tmp2=0.
   endif
   b1(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   a1(j,k)=cmplx(real(aaa(j,ny/2-1,k,4), kind=mytype)*real(b1(j,k), kind=mytype),&
        aimag(aaa(j,ny/2-1,k,4))*aimag(b1(j,k)), kind=mytype)
   eee(j,ny/2-1,k)=cmplx(real(eee(j,ny/2-1,k))*real(b1(j,k))-real(a1(j,k))*real(eee(j,ny/2,k)),&
        aimag(eee(j,ny/2-1,k))*aimag(b1(j,k))-aimag(a1(j,k))*aimag(eee(j,ny/2,k)), kind=mytype)
enddo
enddo

do i=ny/2-2,1,-1
do k=spI%yst(3),spI%yen(3)
do j=spI%yst(1),spI%yen(1) 
   if (abs(real(aaa(j,i,k,3), kind=mytype)).gt.epsilon) then
      tmp1=1./real(aaa(j,i,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,i,k,3))).gt.epsilon) then
      tmp2=1./aimag(aaa(j,i,k,3))
   else
      tmp2=0.
   endif
   sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   a1(j,k)=cmplx(real(aaa(j,i,k,4), kind=mytype)*real(sr(j,k), kind=mytype),&
        aimag(aaa(j,i,k,4))*aimag(sr(j,k)), kind=mytype)
   b1(j,k)=cmplx(real(aaa(j,i,k,5), kind=mytype)*real(sr(j,k), kind=mytype),&
        aimag(aaa(j,i,k,5))*aimag(sr(j,k)), kind=mytype)
   eee(j,i,k)=cmplx(real(eee(j,i,k), kind=mytype)*real(sr(j,k), kind=mytype)-&
        real(a1(j,k), kind=mytype)*real(eee(j,i+1,k), kind=mytype)-&
        real(b1(j,k), kind=mytype)*real(eee(j,i+2,k), kind=mytype),&
        aimag(eee(j,i,k))*aimag(sr(j,k))-&
        aimag(a1(j,k))*aimag(eee(j,i+1,k))-aimag(b1(j,k))*aimag(eee(j,i+2,k)), kind=mytype)
enddo
enddo
enddo

return

end subroutine inversion5_v1 

!*****************************************************************
!
subroutine inversion5_v2(aaa,eee,spI)
!
!*****************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

! decomposition object for spectral space
TYPE(DECOMP_INFO) :: spI

#ifdef DOUBLE_PREC
  real(mytype), parameter :: epsilon = 1.e-16
#else
  real(mytype), parameter :: epsilon = 1.e-8
#endif

complex(mytype),dimension(spI%yst(1):spI%yen(1),nym,spI%yst(3):spI%yen(3),5) :: aaa
complex(mytype),dimension(spI%yst(1):spI%yen(1),nym,spI%yst(3):spI%yen(3)) :: eee
integer :: i,j,k,m,mi,jc
integer,dimension(2) :: ja,jb
complex(mytype),dimension(spI%yst(1):spI%yen(1),spI%yst(3):spI%yen(3)) :: sr
complex(mytype),dimension(spI%yst(1):spI%yen(1),spI%yst(3):spI%yen(3)) :: a1,b1

real(mytype) :: tmp1,tmp2,tmp3,tmp4

do i=1,2
   ja(i)=4-i
   jb(i)=5-i
enddo
do m=1,nym-2
do i=1,2
   mi=m+i
   do k=spI%yst(3),spI%yen(3)
   do j=spI%yst(1),spI%yen(1) 
      if (real(aaa(j,m,k,3), kind=mytype).ne.0.) tmp1=real(aaa(j,mi,k,3-i), kind=mytype)/real(aaa(j,m,k,3), kind=mytype)
      if (aimag(aaa(j,m,k,3)).ne.0.)tmp2=aimag(aaa(j,mi,k,3-i))/aimag(aaa(j,m,k,3))
      sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
      eee(j,mi,k)=cmplx(real(eee(j,mi,k), kind=mytype)-tmp1*real(eee(j,m,k), kind=mytype),&
           aimag(eee(j,mi,k))-tmp2*aimag(eee(j,m,k)), kind=mytype)
   enddo
   enddo
   do jc=ja(i),jb(i)
   do k=spI%yst(3),spI%yen(3)
   do j=spI%yst(1),spI%yen(1) 
      aaa(j,mi,k,jc)=cmplx(real(aaa(j,mi,k,jc), kind=mytype)-real(sr(j,k), kind=mytype)*real(aaa(j,m,k,jc+i), kind=mytype),&
           aimag(aaa(j,mi,k,jc))-aimag(sr(j,k))*aimag(aaa(j,m,k,jc+i)), kind=mytype)
   enddo
   enddo
   enddo
enddo
enddo
do k=spI%yst(3),spI%yen(3)
do j=spI%yst(1),spI%yen(1) 
   if (abs(real(aaa(j,nym-1,k,3), kind=mytype)).gt.epsilon) then
      tmp1=real(aaa(j,nym,k,2), kind=mytype)/real(aaa(j,nym-1,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,nym-1,k,3))).gt.epsilon) then
      tmp2=aimag(aaa(j,nym,k,2))/aimag(aaa(j,nym-1,k,3))
   else
      tmp2=0.
   endif
   sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   b1(j,k)=cmplx(real(aaa(j,nym,k,3), kind=mytype)-tmp1*real(aaa(j,nym-1,k,4), kind=mytype),&
        aimag(aaa(j,nym,k,3))-tmp2*aimag(aaa(j,nym-1,k,4)), kind=mytype)
   if (abs(real(b1(j,k), kind=mytype)).gt.epsilon) then
      tmp1=real(sr(j,k), kind=mytype)/real(b1(j,k), kind=mytype)
      tmp3=real(eee(j,nym,k), kind=mytype)/real(b1(j,k), kind=mytype)-tmp1*real(eee(j,nym-1,k), kind=mytype)
   else
      tmp1=0.
      tmp3=0.
   endif
   if (abs(aimag(b1(j,k))).gt.epsilon) then
      tmp2=aimag(sr(j,k))/aimag(b1(j,k))
      tmp4=aimag(eee(j,nym,k))/aimag(b1(j,k))-tmp2*aimag(eee(j,nym-1,k))
   else
      tmp2=0.
      tmp4=0.
   endif
   a1(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   eee(j,nym,k)=cmplx(tmp3,tmp4, kind=mytype)
   
   if (abs(real(aaa(j,nym-1,k,3), kind=mytype)).gt.epsilon) then
      tmp1=1./real(aaa(j,nym-1,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,nym-1,k,3))).gt.epsilon) then
      tmp2=1./aimag(aaa(j,nym-1,k,3))
   else
      tmp2=0.
   endif
   b1(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   a1(j,k)=cmplx(real(aaa(j,nym-1,k,4), kind=mytype)*real(b1(j,k), kind=mytype),&
        aimag(aaa(j,nym-1,k,4))*aimag(b1(j,k)), kind=mytype)
   eee(j,nym-1,k)=cmplx(real(eee(j,nym-1,k), kind=mytype)*real(b1(j,k), kind=mytype)-&
        real(a1(j,k), kind=mytype)*real(eee(j,nym,k), kind=mytype),&
        aimag(eee(j,nym-1,k))*aimag(b1(j,k))-aimag(a1(j,k))*aimag(eee(j,nym,k)), kind=mytype)
enddo
enddo

do i=nym-2,1,-1
do k=spI%yst(3),spI%yen(3)
do j=spI%yst(1),spI%yen(1) 
   if (abs(real(aaa(j,i,k,3), kind=mytype)).gt.epsilon) then
      tmp1=1./real(aaa(j,i,k,3), kind=mytype)
   else
      tmp1=0.
   endif
   if (abs(aimag(aaa(j,i,k,3))).gt.epsilon) then
      tmp2=1./aimag(aaa(j,i,k,3))
   else
      tmp2=0.
   endif
   sr(j,k)=cmplx(tmp1,tmp2, kind=mytype)
   a1(j,k)=cmplx(real(aaa(j,i,k,4), kind=mytype)*real(sr(j,k), kind=mytype),&
        aimag(aaa(j,i,k,4))*aimag(sr(j,k)), kind=mytype)
   b1(j,k)=cmplx(real(aaa(j,i,k,5), kind=mytype)*real(sr(j,k), kind=mytype),&
        aimag(aaa(j,i,k,5))*aimag(sr(j,k)), kind=mytype)
   eee(j,i,k)=cmplx(real(eee(j,i,k), kind=mytype)*real(sr(j,k), kind=mytype)-&
        real(a1(j,k), kind=mytype)*real(eee(j,i+1,k), kind=mytype)-&
        real(b1(j,k), kind=mytype)*real(eee(j,i+2,k), kind=mytype),&
        aimag(eee(j,i,k))*aimag(sr(j,k))-&
        aimag(a1(j,k))*aimag(eee(j,i+1,k))-aimag(b1(j,k))*aimag(eee(j,i+2,k)), kind=mytype)
enddo
enddo
enddo

return

end subroutine inversion5_v2

!********************************************************************
!
subroutine channel (ux)
!
!********************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: ux

integer :: j,i,k,code
real(mytype) :: can,ut3,ut,ut4

ut3=0.
do k=1,ysize(3)
do i=1,ysize(1)
   ut=0.
   do j=1,ny-1
      if (istret.ne.0) ut=ut+(yp(j+1)-yp(j))*(ux(i,j+1,k)-0.5*(ux(i,j+1,k)-ux(i,j,k)))
      if (istret.eq.0) ut=ut+(yly/(ny-1))*(ux(i,j+1,k)-0.5*(ux(i,j+1,k)-ux(i,j,k)))
   enddo
   ut=ut/yly
   ut3=ut3+ut
enddo
enddo
ut3=ut3/ysize(1)/ysize(3)

call MPI_ALLREDUCE(ut3,ut4,1,real_type,MPI_SUM,MPI_COMM_WORLD,code)
ut4=ut4/nproc

!can=-2.*xnu*gdt(itr) ! Poisseuille    
can=-(2./3.-ut4) ! constant flow rate

if (nrank==0) print *,nrank,'UT',ut4,can

do k=1,ysize(3)
do i=1,ysize(1)
do j=2,ny-1
   ux(i,j,k)=-can+ux(i,j,k)
enddo
enddo
enddo

return
end subroutine channel

!*******************************************************************************
!
subroutine abl (ux) ! Routine to force the abl in periodic boundary conditions
!
!*******************************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: ux
integer :: j,i,k,code
real(mytype) :: can,ut3,ut,ut4, delta

ut3=0.
do k=1,ysize(3)
do i=1,ysize(1)
   ut=0.
   do j=1,ny-1
      if (istret.ne.0) ut=ut+(yp(j+1)-yp(j))*(ux(i,j+1,k)-0.5*(ux(i,j+1,k)-ux(i,j,k)))
      if (istret.eq.0) ut=ut+(yly/(ny-1))*(ux(i,j+1,k)-0.5*(ux(i,j+1,k)-ux(i,j,k)))
   enddo
   !ut=ut/yly
   ut3=ut3+ut
enddo
enddo
ut3=ut3/ysize(1)/ysize(3)

call MPI_ALLREDUCE(ut3,ut4,1,real_type,MPI_SUM,MPI_COMM_WORLD,code)
ut4=ut4/nproc

!can=-(ustar/k_roughness*((1+delta)*(log((1+delta)/z_zero)-1)-delta*(log(delta/z_zero)-1))-ut4) ! constant flow rate for a logarithmic profile
can=-(ustar/k_roughness*yly*(log(yly/z_zero)-1)-ut4) ! constant flow rate for a logarithmic profile
!can=can*yly*2./(yp(ny)+yp(ny-1)-yp(2)-yp(1))

if (nrank==0) print *,nrank,'UT',ut4,can

do k=1,ysize(3)
do i=1,ysize(1)
do j=1,ny
   ux(i,j,k)=-can/yly+ux(i,j,k) ! Force the periodic boundary conditions by assigning the velocity equally ?
enddo
enddo
enddo

return
end subroutine abl

!*******************************************************************************
subroutine damping_zone(ux,uy,uz) ! Damping zone for ABL 
!*******************************************************************************
USE decomp_2d
USE param
USE var

implicit none

real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: ux,uy,uz
integer :: j,i,k,code
real(mytype) :: y, lambda

do k=1,ysize(3)
do i=1,ysize(1)
do j=1,ny
if (istret.eq.0) y=(j-1)*dy
if (istret.ne.0) y=yp(j)
if (y>yly-(yly-dBL)/4) then
    lambda=1.0
elseif (y>dBL.and.y<yly-(yly-dBL)/4) then
    lambda=0.5*(1-cos(pi*(y-dBL)/(yly-(yly-dBL)/4.-dBL)))
else 
    lambda=0.
endif
ux(i,j,k)=lambda*UG(1)+(1-lambda)*ux(i,j,k)
uy(i,j,k)=lambda*UG(2)+(1-lambda)*uy(i,j,k)
uz(i,j,k)=lambda*UG(3)+(1-lambda)*uz(i,j,k)
enddo
enddo
enddo

return
end subroutine damping_zone

!*******************************************************************************
subroutine fringe_region(ux,uy,uz) ! Damping zone for ABL 
!*******************************************************************************
USE decomp_2d
USE param
USE var

implicit none

real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux,uy,uz
integer :: j,i,k,code
real(mytype) :: x, lambda

FLS=xlx/4.-xlx/(4.*6.)
FLE=xlx/4.
FDL=FLE-FLS
do k=1,xsize(3)
do j=1,xsize(2)
do i=1,nx/4
x=(i-1)*dx
if (x<FLs) then
    lambda=0.0
elseif(x.ge.FLS.and.x<FLE-FDL/4.) then
    lambda=0.5*(1-cos(4*pi/3.*(x-FLs)/(FLe-FDL)))
elseif(x.ge.FLE-FDL/4..and.x<FLE) then
    lambda=1.
else 
    lambda=0.
endif
ux(i+3*nx/4,j,k)=lambda*ux(i,j,k)+(1-lambda)*ux(i+3*nx/4,j,k)
uy(i+3*nx/4,j,k)=lambda*uy(i,j,k)+(1-lambda)*uy(i+3*nx/4,j,k)
uz(i+3*nx/4,j,k)=lambda*uz(i,j,k)+(1-lambda)*uz(i+3*nx/4,j,k)
enddo
enddo
enddo
return
end subroutine fringe_region 

subroutine spanwise_shifting(ux3,uy3,uz3) ! periodic shifting

    USE decomp_2d
    USE param

    implicit none
    real(mytype),dimension(zsize(1),zsize(2),zsize(3)) :: ux3,uy3,uz3 
    integer :: i,j,k

    if (zsize(1)>nx/2) then
    do k=1,zsize(3)/2
    do j=1,zsize(2)
    do i=1,zsize(1)
    ux3(i,j,k)=ux3(i,j,k+zsize(3)/2)
    uy3(i,j,k)=uy3(i,j,k+zsize(3)/2)
    uz3(i,j,k)=uz3(i,j,k+zsize(3)/2)
    enddo
    enddo
    enddo
    do k=zsize(3)/2+1,zsize(3)
    do j=1,zsize(2)
    do i=1,zsize(1)
    ux3(i,j,k)=ux3(i,j,k-zsize(3)/2)
    uy3(i,j,k)=uy3(i,j,k-zsize(3)/2)
    uz3(i,j,k)=uz3(i,j,k-zsize(3)/2)
    enddo
    enddo
    enddo

    endif
return

end subroutine spanwise_shifting 

subroutine radial_tripping(time) !TRIPPING SUBROUTINE FOR TURBINE WAKES HARDCODED

USE param
USE var, only: Ftripx, randomtrip 
USE decomp_2d

implicit none

real(mytype),intent(in) :: time
real(mytype) :: x0,y0,z0,Radius
real(mytype) :: etay,etaz,Amp,p_tr,b_tr
real(mytype) :: xmesh,ymesh,zmesh,Rmesh
integer :: i,j,k, itheta, Ntheta
integer :: modes,code,ii

Ftripx(:,:,:)=0. 

! Compute the Torus geometry (hard-coded)
Amp=0.005
Radius=1.
x0=2*Radius
y0=5*Radius
z0=5*Radius
etay=10*dy
etaz=10*dz
do k=1,xsize(3)
    zmesh=(k+xstart(3)-1-1)*dz
    do j=1,xsize(2)
        ymesh=(j+xstart(2)-1-1)*dy
        do i=1,xsize(1)
            xmesh=(i-1)*dx
            rmesh=sqrt((ymesh-y0)**2.+(zmesh-z0)**2.)   
            if(xmesh>x0+0.5*Radius.and.xmesh<x0+2*Radius.and.rmesh<1.25*Radius.and.rmesh>0.75*Radius) then
                Ftripx(i,j,k)=Amp!*dexp(((ymesh-yr)/etay)**2.+((zmesh-zr)/etaz)**2.) ! Only axial
            endif
        enddo
    enddo
enddo

 ! Compute the temporal term
 call system_clock(count=code)
 call random_seed(size = ii)
 call random_seed(put = code+63946*nrank*(/ (i - 1, i = 1, ii) /)) !
 !i=int(time/ts_tr)
 !p_tr=time/ts_tr-i
 !b_tr=3.0*p_tr**2-2.0*p_tr**3

 call random_number(randomtrip)

 if (itripping==1) then ! Noise-symmetric
 Ftripx(:,:,:)=Ftripx(:,:,:)*randomtrip(:,:,:)
 !Creation of tripping Force 
 elseif (itripping==2) then ! Harmonic-symmetric
 Ftripx(:,:,:)=Ftripx(:,:,:)*(sin(2.*2.*pi*time)+sin(5.*2.*pi*time)) 
 endif 

 return   
end subroutine radial_tripping 


subroutine apply_spatial_filter(ux1,uy1,uz1,phi1,ux2,uy2,uz2,phi2,ux3,uy3,uz3,phi3)

USE decomp_2d
USE param
USE var, only: uxf1,uyf1,uzf1,uxf2,uyf2,uzf2,uxf3,uyf3,uzf3,di1,di2,di3,phif1,phif2,phif3

implicit none
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1,phi1
real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: ux2,uy2,uz2,phi2
real(mytype),dimension(zsize(1),zsize(2),zsize(3)) :: ux3,uy3,uz3,phi3
integer :: i,j,k,npaire

call filx(uxf1,ux1,di1,fisx,fiffx,fifsx,fifwx,xsize(1),xsize(2),xsize(3),0) 
call filx(uyf1,uy1,di1,fisx,fiffxp,fifsxp,fifwxp,xsize(1),xsize(2),xsize(3),1) 
call filx(uzf1,uz1,di1,fisx,fiffxp,fifsxp,fifwxp,xsize(1),xsize(2),xsize(3),1)
!call filx(phif1,phi1,di1,fisx,fiffx,fifsx,fifwx,xsize(1),xsize(2),xsize(3),0)
call transpose_x_to_y(uxf1,ux2)
call transpose_x_to_y(uyf1,uy2)
call transpose_x_to_y(uzf1,uz2)
!call transpose_x_to_y(phif1,phi2)
call fily(uxf2,ux2,di2,fisy,fiffyp,fifsyp,fifwyp,ppy,ysize(1),ysize(2),ysize(3),1) 
call fily(uyf2,uy2,di2,fisy,fiffy,fifsy,fifwy,ppy,ysize(1),ysize(2),ysize(3),0) 
call fily(uzf2,uz2,di2,fisy,fiffyp,fifsyp,fifwyp,ppy,ysize(1),ysize(2),ysize(3),1)
!call fily(phif2,phi2,di2,fisy,fiffy,fifsy,fifwy,ppy,ysize(1),ysize(2),ysize(3),0)
call transpose_y_to_z(uxf2,ux3)
call transpose_y_to_z(uyf2,uy3)
call transpose_y_to_z(uzf2,uz3)
!call transpose_y_to_z(phif2,phi3)
call filz(uxf3,ux3,di3,fisz,fiffzp,fifszp,fifwzp,zsize(1),zsize(2),zsize(3),1) 
call filz(uyf3,uy3,di3,fisz,fiffzp,fifszp,fifwzp,zsize(1),zsize(2),zsize(3),1) 
call filz(uzf3,uz3,di3,fisz,fiffz,fifsz,fifwz,zsize(1),zsize(2),zsize(3),0) 
!call filz(phif3,phi3,di3,fisz,fiffz,fifsz,fifwz,zsize(1),zsize(2),zsize(3),0) 
call transpose_z_to_y(uxf3,ux2)
call transpose_z_to_y(uyf3,uy2)
call transpose_z_to_y(uzf3,uz2)
!call transpose_z_to_y(phif3,phi2)
call transpose_y_to_x(ux2,ux1)
call transpose_y_to_x(uy2,uy1)
call transpose_y_to_x(uz2,uz1)
!call transpose_y_to_x(phi2,phi1)

return

end subroutine apply_spatial_filter

!*****************************************************************
!
subroutine collect_data()
!
!*****************************************************************

USE decomp_2d
USE decomp_2d_poisson
USE param
USE var
USE MPI

implicit none

integer :: i,j,imin,ii,code
real(mytype), dimension(200) :: ta
integer,dimension(200) :: tai,tbi

!TOTAL TIME FOR COLLECTION T=50000*0.01=500
!I want 100 files
!100 numbers from 0 to 500

if (nrank==0) then
call random_number(ta)
do i=1,200
   tai(i)=int(ta(i)*2000./dt)
enddo
do j=1,200
imin=999998
ii=0
do i=1,200
   if (tai(i).le.imin) then
      imin=tai(i)
      ii=i
   endif
enddo
tbi(j)=imin
tai(ii)=999999
enddo
idata=tbi
do i=1,200
print *,i,idata(i),'VALUE COLLECTION DATA'
enddo
endif

call MPI_BCAST(idata,200,MPI_INTEGER,0,MPI_COMM_WORLD,code)

end subroutine collect_data
