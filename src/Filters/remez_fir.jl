# linear phase FIR filter design that optimizes maximum error
# in the frequency domain

#=============================================

Translated from C code in scipy into Julia.
Tom Krauss, 2018.

SCIPY license:
Copyright (c) 2001, 2002 Enthought, Inc.
All rights reserved.

Copyright (c) 2003-2017 SciPy Developers.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

  a. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  b. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  c. Neither the name of Enthought nor the names of the SciPy Developers
     may be used to endorse or promote products derived from this software
     without specific prior written permission.


THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
THE POSSIBILITY OF SUCH DAMAGE.

--- end of scipy license

The remez and associated functions were extracted from sigtoolsmodule.c,
with the following header comment:

SIGTOOLS module by Travis Oliphant

Copyright 2005 Travis Oliphant
Permission to use, copy, modify, and distribute this software without fee
is granted under the SciPy License.

C CODE BANNER

/********************************************************
 *
 *  Code taken from remez.c by Erik Kvaleberg which was 
 *    converted from an original FORTRAN by:
 *
 * AUTHORS: JAMES H. MCCLELLAN
 *
 *         DEPARTMENT OF ELECTRICAL ENGINEERING AND COMPUTER SCIENCE
 *         MASSACHUSETTS INSTITUTE OF TECHNOLOGY
 *         CAMBRIDGE, MASS. 02139
 *
 *         THOMAS W. PARKS
 *         DEPARTMENT OF ELECTRICAL ENGINEERING
 *         RICE UNIVERSITY
 *         HOUSTON, TEXAS 77001
 *
 *         LAWRENCE R. RABINER
 *         BELL LABORATORIES
 *         MURRAY HILL, NEW JERSEY 07974
 *
 *  
 *  Adaptation to C by 
 *      egil kvaleberg
 *      husebybakken 14a
 *      0379 oslo, norway
 *  Email:
 *      egil@kvaleberg.no
 *  Web:
 *      http://www.kvaleberg.com/
 *
 *********************************************************/

=============================================#

"""/*
 *-----------------------------------------------------------------------
 * FUNCTION: lagrange_interp (d)
 *  FUNCTION TO CALCULATE THE LAGRANGE INTERPOLATION
 *  COEFFICIENTS FOR USE IN THE FUNCTION gee.
 *-----------------------------------------------------------------------
 */"""
function lagrange_interp(k::Integer, n::Integer, m::Integer, x::AbstractVector)
    retval = 1.0;
    q = x[k];
    for l = 1 : m
        for j = l : m : n
            if j != k
                retval *= 2.0 * (q - x[j])
            end
        end
    end
    1.0 / retval
end


"""
eff(freq::Float64, fx::AbstractVector, lband::Integer, jtype::Integer)

/*
 *-----------------------------------------------------------------------
 * FUNCTION: eff
 *  FUNCTION TO CALCULATE THE DESIRED MAGNITUDE RESPONSE
 *  AS A FUNCTION OF FREQUENCY.
 *  AN ARBITRARY FUNCTION OF FREQUENCY CAN BE
 *  APPROXIMATED IF THE USER REPLACES THIS FUNCTION
 *  WITH THE APPROPRIATE CODE TO EVALUATE THE IDEAL
 *  MAGNITUDE.  NOTE THAT THE PARAMETER FREQ IS THE
 *  VALUE OF NORMALIZED FREQUENCY NEEDED FOR EVALUATION.
 *-----------------------------------------------------------------------
 */
"""
function eff(freq::Float64, fx::AbstractVector, lband::Integer, jtype::Integer)
    if jtype != 2
        return fx[lband]
    else 
        return fx[lband] * freq
    end
end

"""
wate(freq::Float64, fx::AbstractVector, wtx::AbstractVector, lband::Integer, jtype::Integer)
/*
 *-----------------------------------------------------------------------
 * FUNCTION: wate
 *  FUNCTION TO CALCULATE THE WEIGHT FUNCTION AS A FUNCTION
 *  OF FREQUENCY.  SIMILAR TO THE FUNCTION eff, THIS FUNCTION CAN
 *  BE REPLACED BY A USER-WRITTEN ROUTINE TO CALCULATE ANY
 *  DESIRED WEIGHTING FUNCTION.
 *-----------------------------------------------------------------------
 */
"""
function wate(freq::Float64, fx::AbstractVector, wtx::AbstractVector, lband::Integer, jtype::Integer)
    if jtype != 2
        return wtx[lband]
    end
    if fx[lband] >= 0.0001
        return wtx[lband] / freq
    end
    wtx[lband]
end


"""
build_grid(numtaps, bands, desired, weight, grid_density)
return "grid" and "des" and "wt" arrays
"""
function build_grid(numtaps, bands, desired, weight, grid_density, jtype)
    # translate from scipy remez argument names
    L = numtaps
    M = Int(floor(L / 2))
    grid_spacing = 0.5 / (grid_density * M)  # "delf" or "delta f"

    lgrid = grid_density
    dimsize = Int( ceil(numtaps/2.0 + 2) )
    wrksize = grid_density * dimsize

    grid = zeros(Float64, wrksize)  # the array of frequencies, between 0 and 0.5
    des = zeros(Float64, wrksize)   # the desired function on the grid
    wt = zeros(Float64, wrksize)    # array of weights

    fx = desired
    wtx = weight
    
    #jtype = 1
    nbands = length(desired)
    edge = bands
    nfilt = numtaps

    neg = 1
    if jtype == 1
        neg = 0
    end
    nodd = nfilt % 2
    nfcns = nfilt ÷ 2
    if nodd == 1 && neg == 0
        nfcns = nfcns + 1
    end

    """/*
     * SET UP THE DENSE GRID. THE NUMBER OF POINTS IN THE GRID
     * IS (FILTER LENGTH + 1)*GRID DENSITY/2
     */"""
    grid[1] = edge[1]
    delf = lgrid * nfcns
    delf = 0.5 / delf
    if neg != 0
        if edge[1] < delf
            grid[1] = delf
        end
    end
    j = 1
    l = 1
    lband = 1

    """/*
     * CALCULATE THE DESIRED MAGNITUDE RESPONSE AND THE WEIGHT
     * FUNCTION ON THE GRID
     */"""
    while true
        fup = edge[l + 1]
        while true
            temp = grid[j]
            des[j] = eff(temp,fx,lband,jtype)
            wt[j] = wate(temp,fx,wtx,lband,jtype)
            j += 1
            if j > wrksize
                # too many points, or too dense grid
                return -1
            end
            grid[j] = temp + delf
            if grid[j] > fup
                break
            end
        end
        grid[j-1] = fup
        des[j-1] = eff(fup,fx,lband,jtype)
        wt[j-1] = wate(fup,fx,wtx,lband,jtype)
        lband += 1
        l += 2
        if lband > nbands
            break
        end
        grid[j] = edge[l]
    end

    ngrid = j - 1
    if neg == nodd
        if grid[ngrid] > (0.5-delf)
            ngrid -= 1
        end
    end
    
    grid[1:ngrid], des[1:ngrid], wt[1:ngrid]

end

"""
function freq_eval(k::Integer, n::Integer, grid::AbstractVector, 
                   x::AbstractVector, y::AbstractVector, ad::AbstractVector)
-----------------------------------------------------------------------
 FUNCTION: freq_eval (gee)
  FUNCTION TO EVALUATE THE FREQUENCY RESPONSE USING THE
  LAGRANGE INTERPOLATION FORMULA IN THE BARYCENTRIC FORM
-----------------------------------------------------------------------
"""
function freq_eval(k::Integer, n::Integer, grid::AbstractVector, x::AbstractVector, y::AbstractVector, ad::AbstractVector)
    d = 0.0;
    p = 0.0;
    xf = cos((2π)*grid[k])

    for j = 1 : n
        c = ad[j] / (xf - x[j])
        d += c
        p += c * y[j]
    end

    p/d
end

function initialize_y(dev::Float64, nz::Integer, iext::AbstractArray, des::AbstractArray, wt::AbstractArray, y::AbstractArray)
    nu = 1
    if dev > 0.0
        nu = -1
    end
    dev = -nu * dev
    k = nu
    for j = 1 : nz
        l = iext[j]
        y[j] = des[l] + k * dev / wt[l]
        k = -k
    end
    nu, dev
end


"""
    remez(numtaps::Integer, 
          bands::Array, 
          desired::Array; 
          weight::Array=[], 
          Hz::Real=1.0, 
          filter_type::String="bandpass", 
          maxiter::Integer=25, 
          grid_density::Integer=16)

Calculate the minimax optimal filter using the Remez exchange algorithm [^McClellan1973a] [^McClellan1973b].

Calculate the filter-coefficients for the finite impulse response
(FIR) filter whose transfer function minimizes the maximum error
between the desired gain and the realized gain in the specified
frequency bands using the Remez exchange algorithm.

# Arguments
- `numtaps::Integer`: The desired number of taps in the filter. 
    The number of taps is the number of terms in the filter, or the filter 
    order plus one.
- `bands::Array`: A monotonic sequence containing the band edges in Hz.
    All elements must be non-negative and less than half the sampling
    frequency as given by `Hz`.
- `desired::Array`:A sequence half the size of bands containing the desired 
    gain in each of the specified bands.
- `weight::Array`: (optional)
    A relative weighting to give to each band region. The length of
    `weight` has to be half the length of `bands`.
- `Hz::Real`: The sampling frequency in Hz. Default is 1.
- `filter_type::String`: {'bandpass', 'differentiator', 'hilbert'}, optional
    The type of filter:
      'bandpass' : flat response in bands. This is the default.
      'differentiator' : frequency proportional response in bands.
      'hilbert' : filter with odd symmetry, that is, type III
                  (for even order) or type IV (for odd order)
                  linear phase filters.
- `maxiter::Integer`: (optional)
    Maximum number of iterations of the algorithm. Default is 25.
- `grid_density:Integer`: (optional)
    Grid density. The dense grid used in `remez` is of size
    ``(numtaps + 1) * grid_density``. Default is 16.

# Returns
- `h::Array{Float64,1}`: A rank-1 array containing the coefficients of the optimal
    (in a minimax sense) filter.

[^McClellan1973a]: 
J. H. McClellan and T. W. Parks, A unified approach to the
design of optimum FIR linear phase digital filters,
IEEE Trans. Circuit Theory, vol. CT-20, pp. 697-701, 1973.

[^McClellan1973b]: 
J. H. McClellan, T. W. Parks and L. R. Rabiner, A Computer
Program for Designing Optimum FIR Linear Phase Digital
Filters, IEEE Trans. Audio Electroacoust., vol. AU-21,
pp. 506-525, 1973.

# Examples
Construct a length 35 filter with a passband at 0.15-0.4 Hz 
(desired response of 1), and stop bands at 0-0.1 Hz and 0.45-0.5 Hz
(desired response of 0). Note: the behavior in the frequency ranges between 
those bands - the transition bands - is unspecified.

```julia-repl
julia> bpass = remez(35, [0 0.1 0.15 0.4 0.45 0.5], [0 1 0])
```

You can trade-off maximum error achieved for transition bandwidth. 
The wider the transition bands, the lower the maximum error in the
bands specified. Here is a bandpass filter with the same passband, but
wider transition bands.

```julia-repl
julia> bpass2 = remez(35, [0 0.08 0.15 0.4 0.47 0.5], [0 1 0])
```

Here we compute the frequency responses and plot them in dB.

```julia-repl
using PyPlot
b = DSP.Filters.PolynomialRatio(bpass, [1.0]);
b2 = DSP.Filters.PolynomialRatio(bpass2, [1.0]);
f = linspace(0, 0.5, 1000)
plot(f, 20*log10.(abs.(freqz(b,f,1.0))))
plot(f, 20*log10.(abs.(freqz(b2,f,1.0))))
grid()
```
"""
function remez(numtaps::Integer, bands::Array, desired::Array; 
               weight::Array=[], 
               Hz::Real=1.0, 
               filter_type::String="bandpass",
               maxiter::Integer=25, 
               grid_density::Integer=16)
    # Convert type
    if filter_type == "bandpass"
        jtype = 1
    elseif filter_type == "differentiator"
        jtype = 2
    elseif filter_type == "hilbert"
        jtype = 3
    else
        error("`filter_type` must be \"bandpass\", \"differentiator\", or \"hilbert\".")
    end

    if length(weight)==0
        weight = ones(desired)
    end
    bands = copy(bands)/Hz

    bands = vec(bands)   # in C, known as "edge"
    desired = Array{Float64,1}(vec(desired))
    weight = Array{Float64,1}(vec(weight))
    
    grid, des, wt = build_grid(numtaps, bands, desired, weight, grid_density, jtype);

    nfilt = numtaps
    ngrid = length(grid)
    
    #for j = 1 : ngrid
    #    printfmtln("  j={}: grid[j]={}", j, grid[j]);
    #end
    
    # "jtype" is the type of filter, with the following meaning.
      #define BANDPASS       1
      #define DIFFERENTIATOR 2
      #define HILBERT        3
    # I think the "j" is because it is an int, and FORTRAN assigned
    # types based on starting letter of variable name LOL.
    # jtype input:
    #    Type I and II symmetric linear phase: neg==0   (jtype==1)
    #    Type III and IV negative symmetric linear phase: neg==1   (jtype==2 or 3)
    if jtype == 1
      neg = 0
    else
      neg = 1     # "neg" means negative symmetry.
    end
    nodd = numtaps % 2   # nodd == 1: length is odd; nodd == 0: length is even
    nfcns = numtaps ÷ 2  # integer divide
    if nodd == 1 && neg == 0
        nfcns = nfcns + 1
    end
    temp = Float64(ngrid-1) / nfcns
    dimsize = Int64(ceil(numtaps/2.0 + 2))
    #printfmtln("  dimsize={}   nfcns={}", dimsize, nfcns);

    """/*
     * SET UP A NEW APPROXIMATION PROBLEM WHICH IS EQUIVALENT
     * TO THE ORIGINAL PROBLEM
     */"""
    if neg <= 0
        if nodd != 1
            for j = 1 : ngrid
                change = cos(π*grid[j]);
                des[j] = des[j] / change;
                wt[j]  = wt[j] * change;
            end
        end
    else
        if nodd != 1
            for j = 1 : ngrid
                change = sin(π*grid[j]);
                des[j] = des[j] / change;
                wt[j]  = wt[j]  * change;
            end
        else
            for j = 1 : ngrid
                change = sin(2π * grid[j]);
                des[j] = des[j] / change;
                wt[j]  = wt[j]  * change;
            end
        end
    end
        
    iext = vec(zeros(Int64, dimsize))   # indices of extremals
    x = vec(zeros(Float64, dimsize))
    y = vec(zeros(Float64, dimsize))

    for j = 1 : nfcns
        iext[j] = Int64(floor((j-1)*temp)) + 1
    end
    iext[nfcns+1] = ngrid;

    dev = 0.0     # deviation from the desired function, 
                  # that is, the amount of "ripple" on the extremal set
    devl = -1.0;  # deviation on last iteration
    nz  = nfcns+1;
    nzz = nfcns+2;
    niter = 0;
    ad = zeros(Float64, nz)
    
    jet = ((nfcns-1) ÷ 15) + 1

    while true
    
        #
        # Start next iteration
        #        
      @label L100
        iext[nzz] = ngrid + 1;
        niter += 1;
        if niter > maxiter
            break
        end
        
        x[1:nz] = cos.(grid[iext[1:nz]]*2*π)
        #for j = 1 : nz
        #    printfmtln("  j={}: iext[j]={} grid[iext[j]]={} x[j]={}", j, iext[j], grid[iext[j]], x[j]);
        #end
        
        for j = 1 : nz
            ad[j] = lagrange_interp(j, nz, jet, x)
        end

        dnum = 0.0
        dden = 0.0
        k = 1
        for j = 1 : nz
            l = iext[j]
            dnum += ad[j] * des[l]
            dden += k * ad[j] / wt[l]
            k = -k
        end
        dev = dnum / dden
        # printfmtln("DEVIATION = {}", dev);

        y = 0*x
        nu, dev = initialize_y(dev, nz, iext, des, wt, y)
        
        if dev <= devl
            # finished 
            return -1  # error - deviation should always increase
        end        
        devl = dev;

        #
        # SEARCH FOR THE EXTREMAL FREQUENCIES OF THE BEST APPROXIMATION
        #
    
        # Between here and L370, the extremal index set is updated in a loop
        # roughly over the index "j" - although the logic is complicated as
        # the extremal set may grow or shrink in an iteration.
        # j - the index of the current extremal being updated
        # nz - the number of cosines in the approximation (including the constant term).
        #      nz = nfcns + 1 where nfcns = nfilt / 2, and 
        #      nfilt is the filter length or number of taps. 
        #      For example, for a length 15 filter, nfcns = 7 and nz = 8. 
        # jchgne - the number of extremal indices that changed this iteration
        jchnge = 0;
        k1 = iext[1];
        knz = iext[nz];
        klow = 0;
        nut = -nu;
        j = 1;

      @label L200
        if (j == nzz) ynz = comp; end
        if (j >= nzz) @goto L300; end
        kup = iext[j+1];
        l = iext[j]+1;
        nut = -nut;
        if (j == 2) y1 = comp; end
        comp = dev;
        if (l >= kup) @goto L220; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L220; end
        comp = nut * err;
      @label L210
        l += 1; if (l >= kup) @goto L215; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L215; end
        comp = nut * err;
        @goto L210;

      @label L215
        iext[j] = l - 1; j += 1
        klow = l - 1;
        jchnge += 1;
        @goto L200;

      @label L220
        l -= 1;
      @label L225
        l -= 1; if (l <= klow) @goto L250; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) > 0.0) @goto L230; end
        if (jchnge <= 0) @goto L225; end
        @goto L260;

      @label L230
        comp = nut * err;
      @label L235
        l -= 1; if (l <= klow) @goto L240; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L240; end
        comp = nut * err;
        @goto L235;
      @label L240
        klow = iext[j];
        iext[j] = l+1;
        j += 1;
        jchnge += 1;
        @goto L200;

      @label L250
        l = iext[j]+1;
        if (jchnge > 0) @goto L215; end

      @label L255
        l += 1; if (l >= kup) @goto L260; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L255; end
        comp = nut * err;

        @goto L210;
      @label L260
        klow = iext[j]; j += 1
        @goto L200;

      @label L300
        if (j > nzz) @goto L320; end
        if (k1 > iext[1] ) k1 = iext[1]; end
        if (knz < iext[nz]) knz = iext[nz]; end
        nut1 = nut;
        nut = -nu;
        l = 0;
        kup = k1;
        comp = ynz*(1.00001);
        luck = 1;
      @label L310
        l += 1; if (l >= kup) @goto L315; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L310; end
        comp =  nut * err;
        j = nzz;
        @goto L210;

      @label L315
        luck = 6;
        @goto L325;

      @label L320
        if (luck > 9) @goto L350; end
        if (comp > y1) y1 = comp; end
        k1 = iext[nzz];
      @label L325
        l = ngrid+1;
        klow = knz;
        nut = -nut1;
        comp = y1*(1.00001);
      @label L330
        l -= 1; if (l <= klow) @goto L340; end
        err = (freq_eval(l,nz,grid,x,y,ad)-des[l]) * wt[l];
        if ((nut*err-comp) <= 0.0) @goto L330; end
        j = nzz;
        comp =  nut * err;
        luck = luck + 10;
        @goto L235;
      @label L340
        if (luck == 6) @goto L370; end
        for j = 1 : nfcns
            iext[nzz-j] = iext[nz-j];
        end
        iext[1] = k1;
        @goto L100;
      @label L350
        kn = iext[nzz];
        for j = 1 : nfcns
            iext[j] = iext[j+1];
        end
        iext[nz] = kn;

        @goto L100;
      @label L370
        ;
        
        if jchnge <= 0  # we are done if none of the extremal indices changed
            break
        end
    end  # while
    
    # 
    #    CALCULATION OF THE COEFFICIENTS OF THE BEST APPROXIMATION
    #    USING THE INVERSE DISCRETE FOURIER TRANSFORM
    #

    a = vec(zeros(Float64, dimsize))   # frequency response on evenly spaced grid
    p = vec(zeros(Float64, dimsize))
    q = vec(zeros(Float64, dimsize)) 
    alpha = vec(zeros(Float64, dimsize))   # return vector
    
    PI = 3.14159265358979323846
    TWOPI = (PI+PI)
    nm1 = nfcns - 1;   # nm1 => "nfcns minus 1"
    fsh = 1.0e-06;
    gtemp = grid[1];   # grid[1] is temporarily used in freq_eval in this loop
    x[nzz] = -2.0;
    cn  = 2*nfcns - 1;
    delf = 1.0/cn;
    l = 1;
    kkk = 0;

    if (bands[1] == 0.0 && bands[end] == 0.5) kkk = 1; end

    if (nfcns <= 3) kkk = 1; end
    if kkk != 1
        dtemp = cos(TWOPI*grid[1]);
        dnum  = cos(TWOPI*grid[ngrid]);
        aa    = 2.0/(dtemp-dnum);
        bb    = -(dtemp+dnum)/(dtemp-dnum);
    end

    # Fill in "a" array with the frequency response on an evenly
    # spaced set of frequencies. Care is taken to use "y[l]" -
    # an already computed response on one of the extremals "l" -
    # if the extremal is equal to the frequency ft. If no y[l]
    # matches, a[j] is computed using freq_eval.
    for j = 1 : nfcns 
        ft = (j - 1) * delf;
        xt = cos(TWOPI*ft);
        if kkk != 1
            xt = (xt-bb)/aa;
            ft = acos(xt)/TWOPI;
        end
      @label L410
        xe = x[l];
        if (xt > xe) @goto L420; end
        if ((xe-xt) < fsh) @goto L415; end
        l += 1;
        @goto L410;
      @label L415
        a[j] = y[l];
        @goto L425;
      @label L420
        if ((xt-xe) < fsh) @goto L415; end
        grid[1] = ft;
        a[j] = freq_eval(1,nz,grid,x,y,ad);
      @label L425
        if (l > 1) l = l-1; end
    end
    grid[1] = gtemp;  # restore grid[1]
    #for j = 1 : nfcns 
    #    printfmtln("  j={}: a[j]={}", j, a[j]);
    #end

    dden = TWOPI / cn;
    for j = 1 : nfcns
        dtemp = 0.0;
        dnum = (j-1) * dden;
        if nm1 >= 1
            for k = 1 : nm1
                dtemp += a[k+1] * cos(dnum*k);
            end
        end
        alpha[j] = 2.0 * dtemp + a[1];
    end

    for j = 2 : nfcns
        alpha[j] *= 2.0 / cn;
    end
    alpha[1] /= cn;

    if kkk != 1
        p[1] = 2.0*alpha[nfcns]*bb+alpha[nm1];
        p[2] = 2.0*aa*alpha[nfcns];
        q[1] = alpha[nfcns-2]-alpha[nfcns];
        for j = 2 : nm1
            if j >= nm1
                aa *= 0.5;
                bb *= 0.5;
            end
            p[j+1] = 0.0;
            for k = 1 : j
                a[k] = p[k];
                p[k] = 2.0 * bb * a[k];
            end
            p[2] += a[1] * 2.0 *aa;
            jm1 = j - 1;
            for k = 1 : jm1
                p[k] += q[k] + aa * a[k+1];
            end
            jp1 = j + 1;
            for k = 3 : jp1
                p[k] += aa * a[k-1];
            end

            if j != nm1
                for k = 1 : j
                    q[k] = -a[k];
                end
                q[1] += alpha[nfcns - 1 - j];
            end
        end
        for j = 1 : nfcns 
            alpha[j] = p[j];
        end
    end

    if nfcns <= 3
        alpha[nfcns+1] = alpha[nfcns+2] = 0.0;
    end

    #for j = 1 : nfcns 
    #    printfmtln("  j={}: alpha[j]={}", j, alpha[j]);
    #end
    
    #
    # CALCULATE THE IMPULSE RESPONSE.
    #
    h = zeros(Float64, nfilt)
    if neg <= 0
        if nodd != 0
            for j = 1 : nm1
                h[j] = 0.5 * alpha[nz-j];
            end
            h[nfcns] = alpha[1];
        else
            h[1] = 0.25 * alpha[nfcns];
            for j = 2 : nm1
                h[j] = 0.25 * (alpha[nz-j] + alpha[nfcns+2-j]);
            end
            h[nfcns] = 0.5*alpha[1] + 0.25*alpha[2];
        end
    else
        if nodd != 0
            h[1] = 0.25 * alpha[nfcns];
            h[2] = 0.25 * alpha[nm1];
            for j = 1 : nm1
                h[j] = 0.25 * (alpha[nz-j] - alpha[nfcns+3-j]);
            end
            h[nfcns] = 0.5 * alpha[1] - 0.25 * alpha[3];
            h[nz] = 0.0;
        else
            h[1] = 0.25 * alpha[nfcns];
            for j = 2 : nm1
                h[j] = 0.25 * (alpha[nz-j] - alpha[nfcns+2-j]);
            end
            h[nfcns] = 0.5 * alpha[1] - 0.25 * alpha[2];
        end
    end

    for j = 1 : nfcns
        k = nfilt + 1 - j;
        if neg == 0
           h[k] = h[j];
        else
           h[k] = -h[j];
        end
      end
    if (neg == 1 && nodd == 1) h[nz] = 0.0; end
    
    return h
end



