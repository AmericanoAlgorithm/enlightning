c ===========================================================================
c Copyright (C) 2017 Jon Rood.
c
c This file is part of Enlightning source code.
c 
c Enlightning source code is free software; you can redistribute it
c and/or modify it under the terms of the GNU General Public License as
c published by the Free Software Foundation; either version 3 of the License,
c or (at your option) any later version.
c 
c Enlightning source code is distributed in the hope that it will be
c useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
c MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
c GNU General Public License for more details.
c 
c You should have received a copy of the GNU General Public License
c along with Enlightning; if not, see <http://www.gnu.org/licenses/>.
c ===========================================================================

define(NDIM,2)dnl
define(REAL,`double precision')dnl
include(PDAT_FORTDIR/pdat_m4arrdim2d.i)dnl

c This function calculates the RHS using the hybrid scheme with a
c fifth-order WENO subscheme using local lax-friedrichs flux splitting
c and a DRP subscheme.

      subroutine rhs(
     &  ifirst0,ilast0,ifirst1,ilast1,
     &  gcw0,gcw1,
     &  xylo,
     &  dxy,
     &  w_n,
     &  H0,
     &  KK,
     &  pres,
     &  temp,
     &  alpha,
     &  kappa,
     &  mu,
     &  muB,
     &  R,
     &  T_star_n,
     &  T_star_o,
     &  tau_n,
     &  tau_o,
     &  tolerance,
     &  level,
     &  c,
     &  c_lr,
     &  nequ)
c***********************************************************************
      implicit none
cinclude(FORTDIR/const.i)dnl
c***********************************************************************
c***********************************************************************
c input arrays:
      integer ifirst0,ilast0,ifirst1,ilast1
      integer gcw0,gcw1
      REAL alpha
      REAL kappa
      REAL mu
      REAL muB
      REAL R
      REAL T_star_n
      REAL T_star_o
      REAL tau_n
      REAL tau_o
      REAL tolerance(0:2)
      integer level
      REAL c
      REAL c_lr
      integer nequ

      REAL dxy(0:1)
      REAL xylo(0:1)
c
c variables in 2d cell indexed
      REAL
     &     w_n(CELL2dVECG(ifirst,ilast,gcw),0:nequ-1),
     &     H0(CELL2d(ifirst,ilast,0)),
     &     KK(CELL2d(ifirst,ilast,0),0:nequ-1),
     &     pres(CELL2dVECG(ifirst,ilast,gcw)),
     &     temp(CELL2dVECG(ifirst,ilast,gcw))
c
c***********************************************************************
c***********************************************************************     
c
      integer k,q
      integer ix,i,j
      integer ineq,ii,jj
      integer tag
      REAL t_prime_x,t_prime_y,t_dprime_x,t_dprime_y
      REAL u_prime_x,u_prime_y,v_prime_y,v_prime_x
      REAL u_dprime_x,u_dprime_y,v_dprime_xy
      REAL u_dprime_yx,v_dprime_x,v_dprime_y
      REAL phi_xx,phi_xy_yx,phi_yy
      REAL phi_xx_prime_x,phi_xy_prime_y
      REAL phi_yx_prime_x,phi_yy_prime_y
      REAL F(0:7-1,0:nequ-1),G(0:7-1,0:nequ-1),H(0:nequ-1)
      REAL fgm2,fgm1,fg0,fgp1,fgp2
      REAL pf1,pf2,mf1,mf2
      REAL pg1,pg2,mg1,mg2
      REAL wenop,wenom
      REAL Mn,c_vn,A_n
      REAL T_n
      REAL sigma
      REAL a_1,a_2,a_3
      REAL tmp1,tmp2,xi,ep
      REAL rx,ry
      REAL llfalphaf,llfalphag
      REAL height

      xi=1
      ep=0.9*tolerance(2)*(xi**2)/(1-0.9*(tolerance(2)**2))

      a_1=0.79926643
      a_2=-0.18941314
      a_3=0.02651995

      do j=ifirst1,ilast1
         do i=ifirst0,ilast0
            ix = 3
            do q=-3,3
               F(ix+q,0) = w_n(i+q,j,0) *
     &            (w_n(i+q,j,1)/w_n(i+q,j,0))
               G(ix+q,0) = w_n(i,j+q,0) *
     &            (w_n(i,j+q,2)/w_n(i,j+q,0))

               F(ix+q,1) = w_n(i+q,j,0) *
     &            ((w_n(i+q,j,1)/w_n(i+q,j,0))**2) +
     &            pres(i+q,j)
               G(ix+q,1) = w_n(i,j+q,0) *
     &            (w_n(i,j+q,2)/w_n(i,j+q,0)) *
     &            (w_n(i,j+q,1)/w_n(i,j+q,0))

               F(ix+q,2) = w_n(i+q,j,0) *
     &            (w_n(i+q,j,1)/w_n(i+q,j,0)) *
     &            (w_n(i+q,j,2)/w_n(i+q,j,0))
               G(ix+q,2) = w_n(i,j+q,0) *
     &            ((w_n(i,j+q,2)/w_n(i,j+q,0))**2) +
     &            pres(i,j+q)

               F(ix+q,3) = w_n(i+q,j,0) *
     &            (w_n(i+q,j,1)/w_n(i+q,j,0)) *
     &            (w_n(i+q,j,3)/w_n(i+q,j,0))
               G(ix+q,3) = w_n(i,j+q,0) *
     &            (w_n(i,j+q,2)/w_n(i,j+q,0)) *
     &            (w_n(i,j+q,3)/w_n(i,j+q,0))

               F(ix+q,4) = w_n(i+q,j,0) *
     &            (w_n(i+q,j,1)/w_n(i+q,j,0)) *
     &            (w_n(i+q,j,4)/w_n(i+q,j,0))
               G(ix+q,4) = w_n(i,j+q,0) *
     &            (w_n(i,j+q,2)/w_n(i,j+q,0)) *
     &            (w_n(i,j+q,4)/w_n(i,j+q,0))
             end do

            H(0)=H0(i,j)

            u_dprime_x=((w_n(i-1,j,1)/w_n(i-1,j,0)) -
     &         2*(w_n(i,j,1)/w_n(i,j,0)) +
     &         (w_n(i+1,j,1)/w_n(i+1,j,0))) /
     &         (dxy(0)**2)
            u_dprime_y=((w_n(i,j-1,1)/w_n(i,j-1,0)) -
     &         2*(w_n(i,j,1)/w_n(i,j,0)) +
     &         (w_n(i,j+1,1)/w_n(i,j+1,0))) /
     &         (dxy(1)**2)
            v_dprime_xy=((w_n(i+1,j+1,2)/w_n(i+1,j+1,0)) -
     &         (w_n(i+1,j-1,2)/w_n(i+1,j-1,0)) -
     &         (w_n(i-1,j+1,2)/w_n(i-1,j+1,0)) +
     &         (w_n(i-1,j-1,2)/w_n(i-1,j-1,0))) /
     &         (4*dxy(0)*dxy(1))
            phi_xx_prime_x=(4.0/3.0)*u_dprime_x -
     &         (2.0/3.0)*v_dprime_xy
            phi_xy_prime_y=u_dprime_y+v_dprime_xy
            H(1)=muB*(u_dprime_x+v_dprime_xy) +
     &         mu*(phi_xx_prime_x+phi_xy_prime_y)
c            H(1)=0

            v_dprime_y=((w_n(i,j-1,2)/w_n(i,j-1,0)) -
     &         2*(w_n(i,j,2)/w_n(i,j,0)) +
     &         (w_n(i,j+1,2)/w_n(i,j+1,0))) /
     &         (dxy(1)**2)
            v_dprime_x=((w_n(i-1,j,2)/w_n(i-1,j,0)) -
     &         2*(w_n(i,j,2)/w_n(i,j,0)) +
     &         (w_n(i+1,j,2)/w_n(i+1,j,0))) /
     &         (dxy(0)**2)
            u_dprime_yx=((w_n(i+1,j+1,1)/w_n(i+1,j+1,0)) -
     &         (w_n(i+1,j-1,1)/w_n(i+1,j-1,0)) -
     &         (w_n(i-1,j+1,1)/w_n(i-1,j+1,0)) +
     &         (w_n(i-1,j-1,1)/w_n(i-1,j-1,0))) /
     &         (4*dxy(0)*dxy(1))
            phi_yx_prime_x=u_dprime_yx+v_dprime_x
            phi_yy_prime_y=(4.0/3.0)*v_dprime_y-(2.0/3.0)*u_dprime_yx
            H(2)=muB*(v_dprime_y+u_dprime_yx) +
     &         mu*(phi_yx_prime_x+phi_yy_prime_y)
c            H(2)=0

            u_prime_x=((w_n(i+1,j,1)/w_n(i+1,j,0)) -
     &         (w_n(i-1,j,1)/w_n(i-1,j,0)))/(2*dxy(0))
            u_prime_y=((w_n(i,j+1,1)/w_n(i,j+1,0)) -
     &         (w_n(i,j-1,1)/w_n(i,j-1,0)))/(2*dxy(1))
            v_prime_y=((w_n(i,j+1,2)/w_n(i,j+1,0)) -
     &         (w_n(i,j-1,2)/w_n(i,j-1,0)))/(2*dxy(1))
            v_prime_x=((w_n(i+1,j,2)/w_n(i+1,j,0)) -
     &         (w_n(i-1,j,2)/w_n(i-1,j,0)))/(2*dxy(0))
            t_prime_x=(temp(i+1,j)-temp(i-1,j))/(2*dxy(0))
            t_prime_y=(temp(i,j+1)-temp(i,j-1))/(2*dxy(1))
            t_dprime_x=(temp(i-1,j)-2*temp(i,j) +
     &         temp(i+1,j))/(dxy(0)**2)
            t_dprime_y=(temp(i,j-1)-2*temp(i,j) +
     &         temp(i,j+1))/(dxy(1)**2)
            T_n=w_n(i,j,4)/w_n(i,j,0)
            Mn=(temp(i,j)-T_n)/tau_n
            tmp1=T_star_n/(T_n)
            c_vn=0.78*R*(tmp1**2)*exp(-tmp1)
            A_n=((temp(i,j)/T_n)-1)*c_vn
            phi_xx=(4.0/3.0)*u_prime_x-(2.0/3.0)*v_prime_y
            phi_xy_yx=u_prime_y+v_prime_x
            phi_yy=(4.0/3.0)*v_prime_y-(2.0/3.0)*u_prime_x
            sigma=(muB/temp(i,j))*((u_prime_x+v_prime_y)**2) +
     &         (mu/(2*temp(i,j))) *
     &         (phi_xx**2+2*(phi_xy_yx**2)+phi_yy**2) +
     &         (kappa/(temp(i,j)**2)) *
     &         (t_prime_x**2+t_prime_y**2) +
     &         (w_n(i,j,0)/temp(i,j))
     &         *(A_n*Mn)
            H(3)=sigma-
     &         (w_n(i,j,0)/T_n)*c_vn*Mn +
     &         (-((kappa*(t_prime_x**2))/(temp(i,j)**2)) +
     &         ((kappa*t_dprime_x)/temp(i,j)) -
     &         ((kappa*(t_prime_y**2))/(temp(i,j)**2)) +
     &         ((kappa*t_dprime_y)/temp(i,j)))
c            H(3)=0

            H(4)=(w_n(i,j,0)/tau_n)*(temp(i,j)-T_n)

            tag = 1
            if (level .eq. 0) then
               tag = 0

               do q=-1,1
                  tmp1 = w_n(i+q,j,0)-w_n(i-1+q,j,0)
                  tmp2 = w_n(i+1+q,j,0)-w_n(i+q,j,0)
                  rx = (2*abs(tmp1*tmp2)+ep)/(tmp1**2+tmp2**2+ep)
                  if (rx .lt. 0.9999)
     &               tag = 1

                  tmp1 = w_n(i,j+q,0)-w_n(i,j-1+q,0)
                  tmp2 = w_n(i,j+1+q,0)-w_n(i,j+q,0)
                  ry = (2*abs(tmp1*tmp2)+ep)/(tmp1**2+tmp2**2+ep)
                  if (ry .lt. 0.9999)
     &               tag = 1
               end do
            end if

            if (tag .eq. 0) then
               ix=3
               do k=0,nequ-1
                  KK(i,j,k)=
     &               (-a_3*F(ix-3,k)-a_2*F(ix-2,k)-a_1*F(ix-1,k) +
     &               a_1*F(ix+1,k)+a_2*F(ix+2,k)+a_3*F(ix+3,k)) /
     &               (-dxy(0)) +
     &               (-a_3*G(ix-3,k)-a_2*G(ix-2,k)-a_1*G(ix-1,k) +
     &               a_1*G(ix+1,k)+a_2*G(ix+2,k)+a_3*G(ix+3,k)) /
     &               (-dxy(1))+H(k)
               end do
            else
               llfalphaf=0
               llfalphag=0
               do q=-3,3
                  height = xylo(1)+dxy(1)*(dble(j-ifirst1)+0.5)
                  if (abs(w_n(i+q,j,1)/w_n(i+q,j,0))+c+c_lr*height
     &                   .gt. llfalphaf)
     &               llfalphaf=
     &                   abs(w_n(i+q,j,1)/w_n(i+q,j,0))+c+c_lr*height

                  height = xylo(1)+dxy(1)*(dble(j-ifirst1+q)+0.5)
                  if (abs(w_n(i,j+q,2)/w_n(i,j+q,0))+c+c_lr*height
     &                   .gt. llfalphag)
     &               llfalphag=
     &                   abs(w_n(i,j+q,2)/w_n(i,j+q,0))+c+c_lr*height
                end do

               do k=0,nequ-1
                  ii=i-1
                  ix=3-1
                  fgm2 = 0.5*(F(ix-2,k)+llfalphaf*w_n(ii-2,j,k))
                  fgm1 = 0.5*(F(ix-1,k)+llfalphaf*w_n(ii-1,j,k))
                  fg0  = 0.5*(F(ix  ,k)+llfalphaf*w_n(ii  ,j,k))
                  fgp1 = 0.5*(F(ix+1,k)+llfalphaf*w_n(ii+1,j,k))
                  fgp2 = 0.5*(F(ix+2,k)+llfalphaf*w_n(ii+2,j,k))
                  pf1 = wenop(fgm2,fgm1,fg0,fgp1,fgp2)

                  ii=ii+1
                  ix=ix+1
                  fgm2 = 0.5*(F(ix-2,k)-llfalphaf*w_n(ii-2,j,k))
                  fgm1 = 0.5*(F(ix-1,k)-llfalphaf*w_n(ii-1,j,k))
                  fg0  = 0.5*(F(ix  ,k)-llfalphaf*w_n(ii  ,j,k))
                  fgp1 = 0.5*(F(ix+1,k)-llfalphaf*w_n(ii+1,j,k))
                  fgp2 = 0.5*(F(ix+2,k)-llfalphaf*w_n(ii+2,j,k))
                  mf1 = wenom(fgm2,fgm1,fg0,fgp1,fgp2)

                  fgm2 = 0.5*(F(ix-2,k)+llfalphaf*w_n(ii-2,j,k))
                  fgm1 = 0.5*(F(ix-1,k)+llfalphaf*w_n(ii-1,j,k))
                  fg0  = 0.5*(F(ix  ,k)+llfalphaf*w_n(ii  ,j,k))
                  fgp1 = 0.5*(F(ix+1,k)+llfalphaf*w_n(ii+1,j,k))
                  fgp2 = 0.5*(F(ix+2,k)+llfalphaf*w_n(ii+2,j,k))
                  pf2 = wenop(fgm2,fgm1,fg0,fgp1,fgp2)
 
                  ii=ii+1
                  ix=ix+1
                  fgm2 = 0.5*(F(ix-2,k)-llfalphaf*w_n(ii-2,j,k))
                  fgm1 = 0.5*(F(ix-1,k)-llfalphaf*w_n(ii-1,j,k))
                  fg0  = 0.5*(F(ix  ,k)-llfalphaf*w_n(ii  ,j,k))
                  fgp1 = 0.5*(F(ix+1,k)-llfalphaf*w_n(ii+1,j,k))
                  fgp2 = 0.5*(F(ix+2,k)-llfalphaf*w_n(ii+2,j,k))
                  mf2 = wenom(fgm2,fgm1,fg0,fgp1,fgp2)

                  jj=j-1
                  ix=3-1
                  fgm2 = 0.5*(G(ix-2,k)+llfalphag*w_n(i,jj-2,k))
                  fgm1 = 0.5*(G(ix-1,k)+llfalphag*w_n(i,jj-1,k))
                  fg0  = 0.5*(G(ix  ,k)+llfalphag*w_n(i,jj  ,k))
                  fgp1 = 0.5*(G(ix+1,k)+llfalphag*w_n(i,jj+1,k))
                  fgp2 = 0.5*(G(ix+2,k)+llfalphag*w_n(i,jj+2,k))
                  pg1 = wenop(fgm2,fgm1,fg0,fgp1,fgp2)

                  jj=jj+1
                  ix=ix+1
                  fgm2 = 0.5*(G(ix-2,k)-llfalphag*w_n(i,jj-2,k))
                  fgm1 = 0.5*(G(ix-1,k)-llfalphag*w_n(i,jj-1,k))
                  fg0  = 0.5*(G(ix  ,k)-llfalphag*w_n(i,jj  ,k))
                  fgp1 = 0.5*(G(ix+1,k)-llfalphag*w_n(i,jj+1,k))
                  fgp2 = 0.5*(G(ix+2,k)-llfalphag*w_n(i,jj+2,k))
                  mg1 = wenom(fgm2,fgm1,fg0,fgp1,fgp2)

                  fgm2 = 0.5*(G(ix-2,k)+llfalphag*w_n(i,jj-2,k))
                  fgm1 = 0.5*(G(ix-1,k)+llfalphag*w_n(i,jj-1,k))
                  fg0  = 0.5*(G(ix  ,k)+llfalphag*w_n(i,jj  ,k))
                  fgp1 = 0.5*(G(ix+1,k)+llfalphag*w_n(i,jj+1,k))
                  fgp2 = 0.5*(G(ix+2,k)+llfalphag*w_n(i,jj+2,k))
                  pg2 = wenop(fgm2,fgm1,fg0,fgp1,fgp2)

                  jj=jj+1
                  ix=ix+1
                  fgm2 = 0.5*(G(ix-2,k)-llfalphag*w_n(i,jj-2,k))
                  fgm1 = 0.5*(G(ix-1,k)-llfalphag*w_n(i,jj-1,k))
                  fg0  = 0.5*(G(ix  ,k)-llfalphag*w_n(i,jj  ,k))
                  fgp1 = 0.5*(G(ix+1,k)-llfalphag*w_n(i,jj+1,k))
                  fgp2 = 0.5*(G(ix+2,k)-llfalphag*w_n(i,jj+2,k))
                  mg2 = wenom(fgm2,fgm1,fg0,fgp1,fgp2)

                  KK(i,j,k) = (pf1+mf1-pf2-mf2)/dxy(0) + 
     &               (pg1+mg1-pg2-mg2)/dxy(1) + H(k)
               end do
            end if
         end do
      end do

      return
      end

      REAL function wenom(fgm2,fgm1,fg0,fgp1,fgp2)
      REAL fgm2,fgm1,fg0,fgp1,fgp2

      REAL f0,f1,f2
      REAL beta0,beta1,beta2
      REAL zeta0,zeta1,zeta2
      REAL omega0,omega1,omega2
      REAL sigma,ep
      ep = 10.0e-6

      beta0 = (13.0/12.0)*((fg0-2*fgp1+fgp2)**2) +
     &        0.25*((3*fg0-4*fgp1+fgp2)**2)
      beta1 = (13.0/12.0)*((fgm1-2*fg0+fgp1)**2) +
     &        0.25*((fgm1-fgp1)**2)
      beta2 = (13.0/12.0)*((fgm2-2*fgm1+fg0)**2) +
     &        0.25*((fgm2-4*fgm1+3*fg0)**2)

      zeta0 = 0.1/((ep+beta0)**2)
      zeta1 = 0.6/((ep+beta1)**2)
      zeta2 = 0.3/((ep+beta2)**2)

      sigma = zeta0+zeta1+zeta2

      omega0 = zeta0/sigma
      omega1 = zeta1/sigma
      omega2 = zeta2/sigma

      f0 = (1.0/6.0)*(11*fg0-7*fgp1+2*fgp2)
      f1 = (1.0/6.0)*(2*fgm1+5*fg0-fgp1)
      f2 = (1.0/6.0)*(-fgm2+5*fgm1+2*fg0)

      wenom = omega0*f0+omega1*f1+omega2*f2
      return
      end

      REAL function wenop(fgm2,fgm1,fg0,fgp1,fgp2)
      REAL fgm2,fgm1,fg0,fgp1,fgp2

      REAL f0,f1,f2
      REAL beta0,beta1,beta2
      REAL zeta0,zeta1,zeta2
      REAL omega0,omega1,omega2
      REAL sigma,ep
      ep = 10.0e-6

      beta0 = (13.0/12.0)*((fg0-2*fgp1+fgp2)**2) +
     &        0.25*((3*fg0-4*fgp1+fgp2)**2)
      beta1 = (13.0/12.0)*((fgm1-2*fg0+fgp1)**2) +
     &        0.25*((fgm1-fgp1)**2)
      beta2 = (13.0/12.0)*((fgm2-2*fgm1+fg0)**2) +
     &        0.25*((fgm2-4*fgm1+3*fg0)**2)

      zeta0 = 0.3/((ep+beta0)**2)
      zeta1 = 0.6/((ep+beta1)**2)
      zeta2 = 0.1/((ep+beta2)**2)

      sigma = zeta0+zeta1+zeta2

      omega0 = zeta0/sigma
      omega1 = zeta1/sigma
      omega2 = zeta2/sigma

      f0 = (1.0/6.0)*(2*fg0+5*fgp1-fgp2)
      f1 = (1.0/6.0)*(-fgm1+5*fg0+2*fgp1)
      f2 = (1.0/6.0)*(2*fgm2-7*fgm1+11*fg0)

      wenop = omega0*f0+omega1*f1+omega2*f2
      return
      end
