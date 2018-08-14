module PIP_rot
  use globalvar,only:ix,jx,kx,ac,xi_n,gm_rec,gm_ion,nvar_h,nvar_m,&
       flag_pip_imp,gm,n_fraction,t_ir,col,x,y,z,beta
  use scheme_rot,only:get_Te_HD,get_Te_MHD,cq2pv_HD,cq2pv_MHD,get_vel_diff
  use parameters,only:n0,T0,T_r_p,deg1,deg2,pi
  implicit none
  integer,save::col_type,IR_type,xin_type,is_IR,IR_T_dependence
  double precision factor,factor2,mu_p,mu_n,T_ionization
contains
  subroutine initialize_collisional(flag_col)
    integer,intent(inout)::flag_col
    if (flag_col.eq.0) return
    allocate(ac(ix,jx,kx),xi_n(ix,jx,kx))
    if (flag_col.ge.2 .and. flag_col.le.5) then
      col_type=flag_col-1
    else
      col_type=0
    endif
!mod((flag_col/10),10)
    flag_col=mod(flag_col,10)
    T_ionization=T_r_p
    factor=2.7d0*sqrt(T0*T_r_p)*T0*T_r_p/5.6e-16/n0
 !   factor=2.7d0*sqrt(T0*T_r_p)*T0*T_r_p/5.6e-16/n0
!    factor2=1.0d0/((T0/T_r_p)**deg1/factor+(T0/T_r_p)**deg2*exp(-T_r_p/T0))
!    factor2=1.0d0/(T_r_p/T0/factor+sqrt(T0/T_r_p)*exp(-T_r_p/T0))
    factor2=1.0d0/(T_ionization/factor+exp(-T_ionization)/sqrt(T_ionization))

    mu_p=0.5d0
    mu_n=1.0d0
  end subroutine initialize_collisional




  subroutine set_collisional(U_h,U_m)
    double precision,intent(inout)::U_h(ix,jx,kx,nvar_h),U_m(ix,jx,kx,nvar_m)
    double precision,parameter::r_x=0.2d0,r_y=1.0d0,r_z=5.0d0
    double precision,allocatable:: Te_m(:,:,:), Te_h(:,:,:), vd(:,:,:,:)
    integer i,j,k
    select case(col_type)
    case(0)
       ac(:,:,:)=col
    case(1)
    allocate(Te_h(ix,jx,kx), Te_m(ix,jx,kx))
    call get_Te_MHD(U_m,Te_m)
    call get_Te_HD(U_h,Te_h)
    ac(:,:,:)=col*sqrt((Te_h(:,:,:)+Te_m(:,:,:))/2.d0)/sqrt(beta/2.d0*gm/ &
              (2.d0-n_fraction))
    case(2)
    allocate(Te_h(ix,jx,kx), Te_m(ix,jx,kx))
    call get_Te_MHD(U_m,Te_m)
    call get_Te_HD(U_h,Te_h)
    ac(:,:,:)=col*sqrt((Te_h(:,:,:)+Te_m(:,:,:))/2.d0)
    case(3)
    allocate(Te_h(ix,jx,kx), Te_m(ix,jx,kx), vd(ix,jx,kx,3))
    call get_Te_MHD(U_m,Te_m)
    call get_Te_HD(U_h,Te_h)
    call get_vel_diff(vd,U_h,U_m)
    ac(:,:,:)=col*sqrt((Te_h(:,:,:)+Te_m(:,:,:)+pi/4.d0*sum(vd**2,dim=4))/2.d0) &
              /sqrt(beta/2.d0*gm/(2.d0-n_fraction))
    case(4)
    allocate(Te_h(ix,jx,kx), Te_m(ix,jx,kx), vd(ix,jx,kx,3))
    call get_Te_MHD(U_m,Te_m)
    call get_Te_HD(U_h,Te_h)
    call get_vel_diff(vd,U_h,U_m)
    ac(:,:,:)=col*sqrt((Te_h(:,:,:)+Te_m(:,:,:)+pi/4.d0*sum(vd**2,dim=4))/2.d0)

    end select
  end subroutine set_collisional


  subroutine initialize_IR(flag_IR)
    integer,intent(inout)::flag_IR
    if (flag_IR.eq.0) return    
    allocate(Gm_rec(ix,jx,kx),Gm_ion(ix,jx,kx))
    IR_T_dependence=mod((flag_IR/100),10)
    IR_type=mod((flag_IR/10),10)
    flag_IR=mod(flag_IR,10)
    is_IR=flag_IR
  end subroutine initialize_IR

  function rec_temperature(Te)
    double precision Te(ix,jx,kx)
    double precision rec_temperature(ix,jx,kx)
    if(IR_T_dependence.eq.0) then
       rec_temperature=T_ionization/te/factor*factor2       
    else if(IR_T_dependence.eq.1) then
       rec_temperature=n_fraction
    endif
  end function rec_temperature

  function ion_temperature(Te)
    double precision Te(ix,jx,kx)
    double precision ion_temperature(ix,jx,kx)
    if(IR_T_dependence.eq.0) then
       ion_temperature=sqrt(Te/T_ionization)*exp(-T_ionization/Te)*factor2  
    else if(IR_T_dependence.eq.1) then
       ion_temperature=1.0-n_fraction
    endif
  end function ion_temperature

  subroutine set_IR(U_h,U_m)
    double precision,intent(in)::U_h(ix,jx,kx,nvar_h),U_m(ix,jx,kx,nvar_m)
    double precision Te_n(ix,jx,kx),Te_p(ix,jx,kx),Te_e(ix,jx,kx)
    double precision xi_n_tmp(ix,jx,kx)
    select case(IR_type)
    case(0)
       Gm_rec(:,:,:)=n_fraction/t_ir
       Gm_ion(:,:,:)=(1.0d0-n_fraction)/t_ir
    case(1)
!       Gm_rec(:,:,:)=xi_n/t_ir
!       Gm_ion(:,:,:)=(1.0d0-xi_n)/t_ir
       xi_n_tmp=U_h(:,:,:,1)/(U_h(:,:,:,1)+U_m(:,:,:,1))
       Gm_rec(:,:,:)=xi_n_tmp/t_ir
       Gm_ion(:,:,:)=(1.0d0-xi_n_tmp)/t_ir
    case(2)
       !Ioniztion degree and Recombination rate in
       ! rtsa-notes-2003 (3.36) and (3.37)
!       factor=2.7d0*sqrt(T0*T_r_p)*T0*T_r_p/5.6e-16/n0
       call get_Te_HD(U_h,Te_n)
       call get_Te_MHD(U_m,Te_p)    
       !       Gm_rec=(fact2/factor)*(Te_p/T_r_p)**deg1*U_m(:,:,:,1)*U_m(:,:,:,1)
       !       Gm_ion=fact2*(Te_p/T_r_p)**deg2*exp(-T_r_p/Te_p)*U_m(:,:,:,1)
!       Gm_rec=(fact2/factor)*(T_r_p/Te_p)*U_m(:,:,:,1)*U_m(:,:,:,1)
!       Gm_ion=fact2*sqrt(Te_p/T_r_p)*exp(-T_r_p/Te_p)*U_m(:,:,:,1)
       Gm_rec=rec_temperature(Te_p)*U_m(:,:,:,1)*U_m(:,:,:,1)/t_IR
       Gm_ion=ion_temperature(Te_p)*U_m(:,:,:,1)/t_IR
!       print *,"MAXVAL",maxval(GM_rec),maxval(GM_ion),&
!            maxval(ion_temperature(Te_p)+rec_temperature(te_p))
!       stop
    end select
  end subroutine set_IR
  

  subroutine get_initial_xin(Pr_tot,Te_tot,N_tot,xi_n0)
    !return initial xi_n and total number density from
    !  total pressure and temperature
    ! assumption 
    !  -ionization equilibrium
    !    f(T)[f_T] is temperature dependence of ionization and recombination
    !    ionization rate    : nu_ion(T)*n_p*n_n
    !    recombination rate : nu_rec(T)*n_p**3
    !    f(T)=nu_ion(T)/nu_rec(T)
    double precision,intent(in)::Pr_tot(ix,jx,kx),Te_tot(ix,jx,kx)
    double precision,intent(out)::xi_n0(ix,jx,kx),N_tot(ix,jx,kx)
    double precision N_pr(ix,jx,kx),N_i(ix,jx,kx),N_n(ix,jx,kx),f_T(ix,jx,kx)
    f_T=ion_temperature(Te_tot)/rec_temperature(Te_tot)
    N_pr=Pr_tot/Te_tot*gm    
    N_i=-f_T+sqrt(f_T*(f_T+N_pr))
    N_n=N_i*N_i/f_T    
    N_tot=N_i+N_n
    xi_n0=N_n/N_tot        
  end subroutine get_initial_xin

  subroutine get_NT_from_PX(Pr_tot,xi_n0,N_tot,Te_tot)
    !return initial temperature and total number density from
    !  total pressure and neutral fraction
    ! assumption 
    !  -ionization equilibrium
    !    f(T)[f_T] is temperature dependence of ionization and recombination
    !    ionization rate    : nu_ion(T)*n_p*n_n
    !    recombination rate : nu_rec(T)*n_p**3
    !    f(T)=nu_ion(T)/nu_rec(T)
    !    *** f_T must independent of temperature
    double precision,intent(in)::Pr_tot(ix,jx,kx),xi_n0(ix,jx,kx)
    double precision,intent(out)::N_tot(ix,jx,kx)
    double precision,intent(inout)::Te_tot(ix,jx,kx)
    double precision N_pr(ix,jx,kx),N_i(ix,jx,kx),N_n(ix,jx,kx),f_T(ix,jx,kx)
    f_T=ion_temperature(Te_tot)/rec_temperature(Te_tot)
    N_i=xi_n0/(1.0d0-xi_n0)*f_T
    N_n=xi_n0/(1.0d0-xi_n0)*N_i
    N_tot=N_i+N_n
    Te_tot=gm*Pr_tot/(2.0d0*N_i+N_n)    
  end subroutine get_NT_from_PX


  subroutine initialize_xin(flag_amb,flag_col)
    integer,intent(inout)::flag_amb,flag_col
    if (flag_amb.eq.0) return
    if(flag_col.eq.0) flag_col=1
    xin_type=mod((flag_amb/10),10)
    flag_amb=mod(flag_amb,10)
  end subroutine initialize_xin
  
  subroutine set_xin(U_h,U_m)
    double precision,intent(inout)::U_h(ix,jx,kx,nvar_h),U_m(ix,jx,kx,nvar_m)
    integer i,j,k
    double precision,parameter::r_x=10.0d0,r_y=10.0d0,r_z=5.0d0
    double precision tmp,alpha_1,alpha_0
    if(xin_type.eq.0) then
       xi_n=n_fraction
    elseif(xin_type.eq.1)then
       alpha_0=n_fraction/(1-n_fraction)
       alpha_1=1.0d0
       do k=1,kx;do j=1,jx;do i=1,ix
          !       tmp=alpha_0+(alpha_1-alpha_0)*min(1.0d0,y(j)/r_y)
          tmp=alpha_0+(alpha_1-alpha_0)*((tanh((x(i)-r_x)/2.0d0)+1.0d0)*0.5d0 &
               +(1.0d0-tanh((x(i)+r_x)/2.0d0))*0.5d0)
          xi_n(i,j,k)=tmp/(1.0d0+tmp)
       enddo;enddo;enddo       
    endif
  end subroutine set_xin

  !  subroutine source_PIP(U_h0,U_m0,U_h,U_m,dt_coll_i,dt_sub,S_h,S_m)
  subroutine source_PIP(U_h0,U_m0,U_h,U_m,dt_coll_i,S_h,S_m)  
    double precision,intent(inout):: S_h(ix,jx,kx,nvar_h),S_m(ix,jx,kx,nvar_m)
    double precision,intent(inout):: U_h(ix,jx,kx,nvar_h),U_m(ix,jx,kx,nvar_m)
    double precision,intent(inout):: U_h0(ix,jx,kx,nvar_m),U_m0(ix,jx,kx,nvar_m)
    double precision:: dS(ix,jx,kx,nvar_h)
    !    double precision, intent(inout):: dt_coll_i,dt_sub
    double precision, intent(inout):: dt_coll_i
    double precision temp(ix,jx,kx),te(ix,jx,kx),nte(ix,jx,kx)
    double precision pr(ix,jx,kx),npr(ix,jx,kx)
    double precision de(ix,jx,kx),nde(ix,jx,kx)
    double precision vx(ix,jx,kx),nvx(ix,jx,kx)
    double precision vy(ix,jx,kx),nvy(ix,jx,kx)
    double precision vz(ix,jx,kx),nvz(ix,jx,kx)
    double precision bx(ix,jx,kx),by(ix,jx,kx),bz(ix,jx,kx)
    double precision kapper(ix,jx,kx),lambda(ix,jx,kx)
    double precision A(ix,jx,kx),B(ix,jx,kx),D(ix,jx,kx)    
    dS=0.0
    call cq2pv_hd(nde,nvx,nvy,nvz,npr,U_h)
    call cq2pv_mhd(de,vx,vy,vz,pr,bx,by,bz,U_m)
    te=pr/de*gm*mu_p
    nte=npr/nde*gm*mu_n
    
    if(flag_pip_imp.eq.1) then
       temp=dt_coll_i*(u_h(:,:,:,1)+u_m(:,:,:,1))
       dS(:,:,:,2)=(u_m(:,:,:,1)*u_h(:,:,:,2)-u_h(:,:,:,1)*u_m(:,:,:,2)) &
            *(1.0d0-exp(-ac*temp))/temp
       dS(:,:,:,3)=(u_m(:,:,:,1)*u_h(:,:,:,3)-u_h(:,:,:,1)*u_m(:,:,:,3)) &
            *(1.0d0-exp(-ac*temp))/temp          
       dS(:,:,:,4)=(u_m(:,:,:,1)*u_h(:,:,:,4)-u_h(:,:,:,1)*u_m(:,:,:,4)) &
            *(1.0d0-exp(-ac*temp))/temp
       
       lambda=ac*(nde+de)
       kapper=3.0d0*(gm-1.0d0)*ac*(mu_p*nde+mu_n*de)
       
       B=-1.0d0/3.0d0*gm*kapper/((nde+de)*(kapper-lambda))* &
            (de*((nvx-vx)*vx+(nvy-vy)*vy+(nvz-vz)*nvz)+  &
            nde*((nvx-vx)*nvx+(nvy-vy)*nvy+(nvz-vz)*nvz))
       D=-gm/6.0d0*kapper*(de-nde)/((de+nde)*(kapper-2*lambda))* &
            ((nvx-vx)**2+(nvy-vy)**2+(nvz-vz)**2)
       dS(:,:,:,5)=-(3.0d0/gm)*ac*de*nde/kapper*( &
            +(exp(-kapper*dt_coll_i)-1.0d0)*(nte-te)  &
            -(B+D)*exp(-kapper*dt_coll_i) &
            + B*exp(-lambda*dt_coll_i)+D*exp(-2.0d0*lambda*dt_coll_i))/dt_coll_i

       U_h0(:,:,:,1:5)=U_h0(:,:,:,1:5)-dt_coll_i*ds(:,:,:,1:5)
       U_m0(:,:,:,1:5)=U_m0(:,:,:,1:5)+dt_coll_i*ds(:,:,:,1:5)
!       S_h(:,:,:,1:5)=S_h(:,:,:,1:5)-dS(:,:,:,1:5) 
!       S_m(:,:,:,1:5)=S_m(:,:,:,1:5)+dS(:,:,:,1:5) 
    else
       dS(:,:,:,2)=ac*(u_m(:,:,:,1)*u_h(:,:,:,2)-u_h(:,:,:,1)*u_m(:,:,:,2))
       dS(:,:,:,3)=ac*(u_m(:,:,:,1)*u_h(:,:,:,3)-u_h(:,:,:,1)*u_m(:,:,:,3))
       dS(:,:,:,4)=ac*(u_m(:,:,:,1)*u_h(:,:,:,4)-u_h(:,:,:,1)*u_m(:,:,:,4)) 
       dS(:,:,:,5)=ac*nde*de*(0.5d0*((nvx**2-vx**2)+(nvy**2-vy**2)+ &
            (nvz**2-vz**2)) + 3.0d0/gm*(nte-te))       

       S_h(:,:,:,1:5)=S_h(:,:,:,1:5)-dS(:,:,:,1:5) 
       S_m(:,:,:,1:5)=S_m(:,:,:,1:5)+dS(:,:,:,1:5)
    endif

    if(is_IR.ge.1) then
       ds(:,:,:,1)=Gm_rec*de-Gm_ion*nde
       ds(:,:,:,2)=Gm_rec*de*vx-Gm_ion*nde*nvx
       ds(:,:,:,3)=Gm_rec*de*vy-Gm_ion*nde*nvy
       ds(:,:,:,4)=Gm_rec*de*vz-Gm_ion*nde*nvz
       ds(:,:,:,5)=0.5d0*(Gm_rec*de*(vx*vx+vy*vy+vz*vz)- &
            Gm_ion*nde*(nvx*nvx+nvy*nvy+nvz*nvz))
       S_h(:,:,:,1:5)=S_h(:,:,:,1:5)+ds(:,:,:,1:5)
       S_m(:,:,:,1:5)=S_m(:,:,:,1:5)-ds(:,:,:,1:5)
       
    endif    
    return
  end subroutine source_PIP

end module PIP_rot